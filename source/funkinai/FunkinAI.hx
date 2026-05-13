package funkinai;

import haxe.Json;
import funkinai.FunkinAIConfig;

#if sys
import sys.thread.Thread;
import sys.thread.Deque;
#end

private typedef Message =
{
	role:String,
	content:String
};

private typedef QueueItem =
{
	success:Bool,
	payload:String,
	attempt:Int
};

class FunkinAI
{
	public var onResponse:String -> Void;
	public var onError:String -> Void;
	public var onThinking:Void -> Void;
	public var onRetry:Int -> Void;

	public var history:Array<Message> = [];
	public var isBusy(default, null):Bool = false;

	#if sys
	var _queue:Deque<QueueItem>;
	#end

	var _attempt:Int = 0;
	var _timeoutTimer:Float = 0;
	var _lastSendTime:Float = 0;

	public function new()
	{
		#if sys
		_queue = new Deque<QueueItem>();
		#end
		FunkinAIConfig.loadApiKey();
	}

	public function send(msg:String):Void
	{
		if (isBusy) return;

		msg = StringTools.trim(msg);
		if (msg.length == 0) return;

		if (haxe.Timer.stamp() - _lastSendTime < FunkinAIConfig.RATE_LIMIT_INTERVAL) return;

		history.push({role: "user", content: msg});
		_trimHistory();

		_attempt = 0;
		isBusy = true;
		_timeoutTimer = 0;

		if (onThinking != null) onThinking();
		_fireRequest();
	}

	public function update(elapsed:Float):Void
	{
		#if sys
		var item = _queue.pop(false);
		if (item != null)
		{
			if (item.success)
				_succeed(item.payload);
			else if (item.attempt < FunkinAIConfig.MAX_RETRIES)
				_scheduleRetry(item.attempt + 1, item.payload);
			else
				_fail(item.payload);
		}
		#end

		if (isBusy)
		{
			_timeoutTimer += elapsed;
			if (_timeoutTimer >= FunkinAIConfig.REQUEST_TIMEOUT)
				_fail("Request timed out after " + Std.int(FunkinAIConfig.REQUEST_TIMEOUT) + "s.");
		}
	}

	public function reset():Void
	{
		history = [];
		isBusy = false;
		_attempt = 0;
		_timeoutTimer = 0;
	}

	function _fireRequest():Void
	{
		#if sys
		Thread.create(_doRequest);
		#else
		_doRequest();
		#end
	}

	function _doRequest():Void
	{
		var msgs:Array<Dynamic> = [for (m in history) {role: m.role, content: m.content}];

		var body = Json.stringify({
			model:      FunkinAIConfig.MODEL,
			max_tokens: FunkinAIConfig.MAX_TOKENS,
			system:     FunkinAIConfig.SYSTEM_PROMPT,
			messages:   msgs
		});

		var http = new haxe.Http(FunkinAIConfig.API_URL);
		http.addHeader("x-api-key",        FunkinAIConfig.API_KEY);
		http.addHeader("anthropic-version", FunkinAIConfig.API_VERSION);
		http.addHeader("content-type",      "application/json");
		http.setPostData(body);

		http.onData = function(raw:String)
		{
			try
			{
				var parsed:Dynamic = Json.parse(raw);
				if (parsed.error != null)
				{
					_pushResult(false, _parseApiError(parsed.error), _attempt);
					return;
				}
				var text:String = StringTools.trim(cast(parsed.content[0].text, String));
				_pushResult(true, text, 0);
			}
			catch (e:Dynamic)
			{
				_pushResult(false, "Parse error: " + Std.string(e), _attempt);
			}
		};

		http.onError = function(err:String)
		{
			_pushResult(false, err, _attempt);
		};

		http.request(true);
	}

	function _pushResult(success:Bool, payload:String, attempt:Int):Void
	{
		#if sys
		_queue.push({success: success, payload: payload, attempt: attempt});
		#else
		if (success)
			_succeed(payload);
		else if (attempt < FunkinAIConfig.MAX_RETRIES)
			_scheduleRetry(attempt + 1, payload);
		else
			_fail(payload);
		#end
	}

	function _scheduleRetry(attempt:Int, lastErr:String):Void
	{
		_attempt = attempt;
		_timeoutTimer = 0;
		if (onRetry != null) onRetry(attempt);

		#if sys
		Thread.create(function()
		{
			Sys.sleep(FunkinAIConfig.RETRY_DELAY);
			_fireRequest();
		});
		#else
		_fireRequest();
		#end
	}

	function _succeed(text:String):Void
	{
		history.push({role: "assistant", content: text});
		_trimHistory();
		_lastSendTime = haxe.Timer.stamp();
		isBusy = false;
		if (onResponse != null) onResponse(text);
	}

	function _fail(msg:String):Void
	{
		if (history.length > 0 && history[history.length - 1].role == "user")
			history.pop();
		isBusy = false;
		if (onError != null) onError(msg);
	}

	function _parseApiError(err:Dynamic):String
	{
		var type:String = err.type != null ? Std.string(err.type) : "";
		return switch (type)
		{
			case "authentication_error":   "Invalid API key. Set it in funkinai.json.";
			case "rate_limit_error":       "Rate limit reached. Wait a moment.";
			case "overloaded_error":       "Claude is overloaded. Try again soon.";
			case "invalid_request_error":  err.message != null ? Std.string(err.message) : "Invalid request.";
			default:                       err.message != null ? Std.string(err.message) : "Unknown API error.";
		}
	}

	function _trimHistory():Void
	{
		while (history.length > FunkinAIConfig.MAX_HISTORY)
			history.shift();
	}
}
