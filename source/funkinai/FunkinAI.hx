package funkinai;

import haxe.Json;
import haxe.Http;

#if sys
import sys.thread.Thread;
import sys.thread.Mutex;
#end

class FunkinAI
{
	public typedef Message =
	{
		role:String,
		content:String
	};

	public var onResponse:String -> Void;
	public var onError:String -> Void;
	public var onThinking:Void -> Void; // called when request starts

	public var history:Array<Message> = [];

	public var isBusy(default, null):Bool = false;

	#if sys
	var pendingResponse:Null<String> = null;
	var pendingError:Null<String> = null;
	var mutex:Mutex;
	#end

	public function new()
	{
		#if sys
		mutex = new Mutex();
		#end
	}

	public function send(userMessage:String):Void
	{
		if (isBusy)
			return;

		userMessage = StringTools.trim(userMessage);
		if (userMessage.length == 0)
			return;

		history.push({role: "user", content: userMessage});
		trimHistory();

		isBusy = true;

		if (onThinking != null)
			onThinking();

		#if sys
		Thread.create(_threadedRequest);
		#else
		_request();
		#end
	}

	public function update():Void
	{
		#if sys
		mutex.acquire();
		var resp = pendingResponse;
		var err = pendingError;
		pendingResponse = null;
		pendingError = null;
		mutex.release();

		if (resp != null)
			_dispatchResponse(resp);
		else if (err != null)
			_dispatchError(err);
		#end
	}

	public function reset():Void
	{
		history = [];
	}

	function _request():Void
	{
		var messages:Array<Dynamic> = [];
		for (msg in history)
			messages.push({role: msg.role, content: msg.content});

		var body:Dynamic = {
			model: FunkinAIConfig.MODEL,
			max_tokens: FunkinAIConfig.MAX_TOKENS,
			system: FunkinAIConfig.SYSTEM_PROMPT,
			messages: messages
		};

		var bodyJson = Json.stringify(body);

		var http = new haxe.Http(FunkinAIConfig.API_URL);
		http.addHeader("x-api-key", FunkinAIConfig.API_KEY);
		http.addHeader("anthropic-version", FunkinAIConfig.API_VERSION);
		http.addHeader("content-type", "application/json");
		http.setPostData(bodyJson);

		http.onData = function(data:String)
		{
			try
			{
				var parsed = Json.parse(data);
				var text:String = parsed.content[0].text;
				text = StringTools.trim(text);

				history.push({role: "assistant", content: text});
				trimHistory();

				#if sys
				mutex.acquire();
				pendingResponse = text;
				mutex.release();
				#else
				_dispatchResponse(text);
				#end
			}
			catch (e:Dynamic)
			{
				var errMsg = "Failed to parse API response: " + Std.string(e);
				#if sys
				mutex.acquire();
				pendingError = errMsg;
				mutex.release();
				#else
				_dispatchError(errMsg);
				#end
			}
		};

		http.onError = function(errMsg:String)
		{
			#if sys
			mutex.acquire();
			pendingError = "API error: " + errMsg;
			mutex.release();
			#else
			_dispatchError("API error: " + errMsg);
			#end
		};

		http.request(true); // POST
	}

	/** Entry point for background thread (sys targets only) */
	function _threadedRequest():Void
	{
		#if sys
		_request();
		#end
	}

	function _dispatchResponse(text:String):Void
	{
		isBusy = false;
		if (onResponse != null)
			onResponse(text);
	}

	function _dispatchError(msg:String):Void
	{
		if (history.length > 0 && history[history.length - 1].role == "user")
			history.pop();

		isBusy = false;
		if (onError != null)
			onError(msg);
	}

	/** Keep history within the configured limit to avoid huge API payloads */
	function trimHistory():Void
	{
		var limit = FunkinAIConfig.MAX_HISTORY_MESSAGES;
		while (history.length > limit)
			history.shift();
	}
}
