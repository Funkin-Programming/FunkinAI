package funkinai;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.events.TextEvent;
import openfl.events.KeyboardEvent as OFLKey;
import openfl.ui.Keyboard;
import funkinai.FunkinAI;
import funkinai.FunkinAIConfig;

enum abstract ChatState(Int)
{
	var IDLE    = 0;
	var SENDING = 1;
	var TYPING  = 2;
}

class FunkinAIChatUI extends FlxGroup
{
	static inline var W:Float       = 500;
	static inline var H:Float       = 390;
	static inline var PAD:Float     = 10;
	static inline var TITLE_H:Float = 32;
	static inline var STATUS_H:Float = 22;
	static inline var INPUT_H:Float  = 36;
	static inline var SB_W:Float     = 6;
	static inline var SEND_W:Float   = 60;
	static inline var FONT:Int       = 12;
	static inline var FONT_T:Int     = 14;
	static inline var MSG_AREA_Y:Float  = TITLE_H + STATUS_H;
	static inline var MSG_AREA_H:Float  = H - MSG_AREA_Y - INPUT_H - PAD * 2 - 4;
	static inline var SLOT_H:Float      = MSG_AREA_H / FunkinAIConfig.MAX_VISIBLE;

	var _ai:FunkinAI;
	var _state:ChatState = IDLE;
	var _isVisible:Bool = false;

	var _panelX:Float;
	var _panelY:Float;
	var _dragging:Bool = false;
	var _dragOX:Float = 0;
	var _dragOY:Float = 0;

	var _input:String = "";
	var _lastInput:String = "";
	var _cursorTimer:Float = 0;
	var _cursorOn:Bool = true;

	var _messages:Array<{role:String, text:String}> = [];
	var _scrollIdx:Int = 0;

	var _typingFull:String = "";
	var _typingProg:Float = 0;

	var _dotTimer:Float = 0;
	var _dotIdx:Int = 0;
	static final DOTS:Array<String> = ["•  ", "•• ", "•••"];

	var _panel:FlxSprite;
	var _titleBar:FlxSprite;
	var _titleText:FlxText;
	var _closeBtn:FlxText;
	var _clearBtn:FlxText;
	var _statusText:FlxText;
	var _msgArea:FlxSprite;
	var _slots:Array<FlxText> = [];
	var _scrollBg:FlxSprite;
	var _scrollThumb:FlxSprite;
	var _inputBg:FlxSprite;
	var _inputDisplay:FlxText;
	var _sendBg:FlxSprite;
	var _sendLabel:FlxText;

	public function new()
	{
		super();

		_panelX = Math.round((FlxG.width  - W) / 2.0);
		_panelY = Math.round((FlxG.height - H) / 2.0);

		_ai = new FunkinAI();
		_ai.onResponse = _onResponse;
		_ai.onError    = _onError;
		_ai.onThinking = _onThinking;
		_ai.onRetry    = _onRetry;

		_build();
		_addListeners();
		_pushSys("FunkinAI ready! Ask me anything about FNF 🎵");
		_setVisible(false);
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);
		_ai.update(elapsed);

		if (FlxG.keys.justPressed.TAB)
			_setVisible(!_isVisible);

		if (!_isVisible) return;

		_tickCursor(elapsed);
		_tickTyping(elapsed);
		_tickDots(elapsed);
		_handleMouse();
		_handleDrag();
		_updateScrollThumb();
	}

	override public function destroy():Void
	{
		_removeListeners();
		super.destroy();
	}

	function _build():Void
	{
		var px = _panelX;
		var py = _panelY;

		_panel = _spr(px, py, W, H, FunkinAIConfig.C_PANEL);
		add(_panel);

		_titleBar = _spr(px, py, W, TITLE_H, FunkinAIConfig.C_TITLEBAR);
		add(_titleBar);

		_titleText = _txt(px + PAD, py + 8, W - 90, "🎵 FunkinAI", FONT_T, FlxColor.WHITE);
		_titleText.setBorderStyle(SHADOW, FlxColor.fromRGB(0, 0, 0, 100), 1);
		add(_titleText);

		_clearBtn = _txt(px + W - 72, py + 8, 30, "CLR", FONT - 1, FlxColor.fromRGB(255, 200, 200));
		add(_clearBtn);

		_closeBtn = _txt(px + W - 28, py + 7, 20, "✕", FONT_T, FlxColor.WHITE);
		add(_closeBtn);

		_statusText = _txt(px + PAD, py + TITLE_H + 3, W - PAD * 2, "", FONT - 1, FunkinAIConfig.C_STATUS_OK);
		add(_statusText);

		_msgArea = _spr(px + PAD, py + MSG_AREA_Y, W - PAD * 2 - SB_W - 2, MSG_AREA_H, FunkinAIConfig.C_MSGAREA);
		add(_msgArea);

		var slotW = W - PAD * 2 - SB_W - 2 - 8;
		for (i in 0...FunkinAIConfig.MAX_VISIBLE)
		{
			var sy = py + MSG_AREA_Y + i * SLOT_H + 4;
			var t  = _txt(px + PAD + 4, sy, slotW, "", FONT, FlxColor.WHITE);
			t.wordWrap   = false;
			t.autoSize   = false;
			t.fieldHeight = SLOT_H - 2;
			_slots.push(t);
			add(t);
		}

		var sbX = px + W - PAD - SB_W;
		var sbY = py + MSG_AREA_Y;
		_scrollBg = _spr(sbX, sbY, SB_W, MSG_AREA_H, FunkinAIConfig.C_SCROLLBG);
		add(_scrollBg);

		_scrollThumb = _spr(sbX, sbY, SB_W, 20, FunkinAIConfig.C_SCROLLTHUMB);
		_scrollThumb.visible = false;
		add(_scrollThumb);

		var inputY = py + H - INPUT_H - PAD;
		_inputBg = _spr(px + PAD, inputY, W - PAD * 2 - SEND_W - 4, INPUT_H, FunkinAIConfig.C_INPUT);
		add(_inputBg);

		_inputDisplay = _txt(px + PAD + 6, inputY + 11, W - PAD * 2 - SEND_W - 16, "", FONT, FlxColor.WHITE);
		add(_inputDisplay);

		_sendBg = _spr(px + W - PAD - SEND_W, inputY, SEND_W, INPUT_H, FunkinAIConfig.C_SEND);
		add(_sendBg);

		_sendLabel = _txt(px + W - PAD - SEND_W, inputY + 11, SEND_W, "Send", FONT, FlxColor.WHITE);
		_sendLabel.alignment = CENTER;
		add(_sendLabel);
	}

	function _addListeners():Void
	{
		FlxG.stage.addEventListener(TextEvent.TEXT_INPUT, _onTextInput);
		FlxG.stage.addEventListener(OFLKey.KEY_DOWN,      _onStageKey);

		#if mobile
		lime.app.Application.current.window.textInputEnabled = true;
		#end
	}

	function _removeListeners():Void
	{
		FlxG.stage.removeEventListener(TextEvent.TEXT_INPUT, _onTextInput);
		FlxG.stage.removeEventListener(OFLKey.KEY_DOWN,      _onStageKey);
	}

	function _setVisible(v:Bool):Void
	{
		_isVisible = v;
		forEach(function(m:flixel.FlxBasic) m.visible = v);

		if (v)
		{
			var targetX = _panelX;
			_moveAll(_panelX + W, _panelY);
			_panel.x = _panelX + W;
			FlxTween.tween(_panel, {x: targetX}, 0.22, {ease: FlxEase.expoOut, onUpdate: function(_)
			{
				var dx = _panel.x - (_panelX + W);
				_panelX = _panel.x;
				forEach(function(m:flixel.FlxBasic)
				{
					var o = cast(m, flixel.FlxObject);
					if (o != _panel) o.x = _panel.x + (o.x - (_panelX + W));
				});
			}});
			_refreshDisplay();
		}
	}

	function _tickCursor(elapsed:Float):Void
	{
		_cursorTimer += elapsed;
		if (_cursorTimer >= 0.53)
		{
			_cursorTimer = 0;
			_cursorOn = !_cursorOn;
			_refreshInput();
		}
	}

	function _tickTyping(elapsed:Float):Void
	{
		if (_state != TYPING) return;

		_typingProg += FunkinAIConfig.TYPING_CPS * elapsed;
		var idx = Std.int(Math.min(_typingProg, _typingFull.length));

		if (_messages.length > 0)
			_messages[_messages.length - 1].text = _typingFull.substr(0, idx);

		_refreshDisplay();

		if (_typingProg >= _typingFull.length)
		{
			_messages[_messages.length - 1].text = _typingFull;
			_state = IDLE;
			_refreshDisplay();
			_setStatus("", FunkinAIConfig.C_STATUS_OK);
		}
	}

	function _tickDots(elapsed:Float):Void
	{
		if (_state != SENDING) return;
		_dotTimer += elapsed;
		if (_dotTimer >= 0.38)
		{
			_dotTimer = 0;
			_dotIdx = (_dotIdx + 1) % DOTS.length;
			_setStatus("Thinking " + DOTS[_dotIdx], FunkinAIConfig.C_STATUS_WAIT);
		}
	}

	function _handleMouse():Void
	{
		var wheel = FlxG.mouse.wheel;
		if (wheel != 0) _scroll(-wheel);

		if (!FlxG.mouse.justPressed) return;

		if (_hitsBtn(_closeBtn)) { _setVisible(false); return; }
		if (_hitsBtn(_clearBtn)) { _clearHistory(); return; }
		if (_hitsSend() && _state == IDLE) { _submit(); return; }

		#if mobile
		if (_hitsInputArea())
			lime.app.Application.current.window.textInputEnabled = true;
		#end
	}

	function _handleDrag():Void
	{
		if (FlxG.mouse.justPressed && _hitsTitleBar())
		{
			_dragging = true;
			_dragOX = FlxG.mouse.x - _panelX;
			_dragOY = FlxG.mouse.y - _panelY;
		}

		if (FlxG.mouse.released) _dragging = false;

		if (_dragging)
		{
			var nx = FlxMath.bound(FlxG.mouse.x - _dragOX, 0, FlxG.width  - W);
			var ny = FlxMath.bound(FlxG.mouse.y - _dragOY, 0, FlxG.height - H);
			_moveAll(nx, ny);
		}
	}

	function _updateScrollThumb():Void
	{
		var total   = _messages.length;
		var visible = FunkinAIConfig.MAX_VISIBLE;

		if (total <= visible)
		{
			_scrollThumb.visible = false;
			return;
		}

		_scrollThumb.visible = true;
		var trackH  = MSG_AREA_H - 4;
		var thumbH  = Math.max(14, trackH * visible / total);
		var ratio   = _scrollIdx / (total - visible);
		var thumbY  = _panelY + MSG_AREA_Y + 2 + ratio * (trackH - thumbH);

		_scrollThumb.y      = thumbY;
		_scrollThumb.height = thumbH;
	}

	function _submit():Void
	{
		var msg = StringTools.trim(_input);
		if (msg.length == 0 || _ai.isBusy) return;

		_lastInput = msg;
		_input     = "";
		_refreshInput();
		_pushMsg("user", msg);
		_ai.send(msg);
	}

	function _scroll(delta:Int):Void
	{
		var max = Std.int(Math.max(0, _messages.length - FunkinAIConfig.MAX_VISIBLE));
		_scrollIdx = Std.int(Math.max(0, Math.min(_scrollIdx + delta, max)));
		_refreshDisplay();
	}

	function _autoScroll():Void
	{
		_scrollIdx = Std.int(Math.max(0, _messages.length - FunkinAIConfig.MAX_VISIBLE));
	}

	function _refreshDisplay():Void
	{
		var from = _scrollIdx;
		for (i in 0...FunkinAIConfig.MAX_VISIBLE)
		{
			var mi = from + i;
			var slot = _slots[i];
			if (mi < _messages.length)
			{
				var msg  = _messages[mi];
				slot.text  = msg.text;
				slot.color = switch (msg.role)
				{
					case "user":   FlxColor.fromInt(FunkinAIConfig.C_USER);
					case "system": FlxColor.fromInt(FunkinAIConfig.C_SYSTEM);
					default:       FlxColor.fromInt(FunkinAIConfig.C_AI);
				}
				slot.visible = true;
			}
			else
			{
				slot.text    = "";
				slot.visible = false;
			}
		}
	}

	function _refreshInput():Void
	{
		if (_input.length == 0 && _state == IDLE)
		{
			_inputDisplay.text  = "Ask about FNF...";
			_inputDisplay.color = FlxColor.fromInt(FunkinAIConfig.C_PLACEHOLDER);
			return;
		}
		var cursor = (_cursorOn && _state == IDLE) ? "|" : "";
		_inputDisplay.text  = _input + cursor;
		_inputDisplay.color = FlxColor.WHITE;
	}

	function _setStatus(msg:String, color:Int):Void
	{
		_statusText.text  = msg;
		_statusText.color = FlxColor.fromInt(color);
	}

	function _clearHistory():Void
	{
		_messages = [];
		_scrollIdx = 0;
		_ai.reset();
		_refreshDisplay();
		_pushSys("History cleared.");
	}

	function _pushMsg(role:String, text:String):Void
	{
		_messages.push({role: role, text: text});
		_autoScroll();
		_refreshDisplay();
	}

	function _pushSys(text:String):Void
	{
		_pushMsg("system", text);
	}

	function _onTextInput(e:openfl.events.TextEvent):Void
	{
		if (!_isVisible || _state != IDLE) return;

		var ch = e.text;
		if (ch == "\n" || ch == "\r") { _submit(); return; }
		if (_input.length < FunkinAIConfig.MAX_INPUT_LENGTH)
		{
			_input += ch;
			_cursorOn    = true;
			_cursorTimer = 0;
			_refreshInput();
		}
	}

	function _onStageKey(e:OFLKey):Void
	{
		if (!_isVisible) return;

		switch (e.keyCode)
		{
			case Keyboard.BACKSPACE:
				if (_state == IDLE && _input.length > 0)
				{
					_input = _input.substr(0, _input.length - 1);
					_cursorOn    = true;
					_cursorTimer = 0;
					_refreshInput();
				}

			case Keyboard.ENTER:
				if (_state == IDLE) _submit();

			case Keyboard.UP:
				if (_input.length == 0 && _lastInput.length > 0 && _state == IDLE)
				{
					_input = _lastInput;
					_cursorOn    = true;
					_cursorTimer = 0;
					_refreshInput();
				}
				else _scroll(-1);

			case Keyboard.DOWN:
				_scroll(1);

			case Keyboard.L:
				if (e.ctrlKey) _clearHistory();
		}
	}

	function _onThinking():Void
	{
		_state    = SENDING;
		_dotTimer = 0;
		_dotIdx   = 0;
		_setStatus("Thinking " + DOTS[0], FunkinAIConfig.C_STATUS_WAIT);
		_sendBg.color = FlxColor.fromInt(FunkinAIConfig.C_SEND_BUSY);
		_sendLabel.color = FlxColor.fromRGB(200, 150, 170);
	}

	function _onResponse(text:String):Void
	{
		_pushMsg("ai", "");

		_typingFull = text;
		_typingProg = 0;
		_state = TYPING;

		_sendBg.color    = FlxColor.fromInt(FunkinAIConfig.C_SEND);
		_sendLabel.color = FlxColor.WHITE;
	}

	function _onError(msg:String):Void
	{
		_state = IDLE;
		_pushSys("⚠ " + msg);
		_setStatus("Error — try again.", FunkinAIConfig.C_STATUS_ERR);
		_sendBg.color    = FlxColor.fromInt(FunkinAIConfig.C_SEND);
		_sendLabel.color = FlxColor.WHITE;
	}

	function _onRetry(attempt:Int):Void
	{
		_setStatus("Retrying (" + attempt + "/" + FunkinAIConfig.MAX_RETRIES + ")…", FunkinAIConfig.C_STATUS_WAIT);
	}

	function _hitsTitleBar():Bool
		return _mouseIn(_panelX, _panelY, W, TITLE_H);

	function _hitsBtn(t:FlxText):Bool
		return _mouseIn(t.x, t.y, t.width + 8, t.height + 8);

	function _hitsSend():Bool
		return _mouseIn(_sendBg.x, _sendBg.y, SEND_W, INPUT_H);

	function _hitsInputArea():Bool
		return _mouseIn(_inputBg.x, _inputBg.y, _inputBg.width, INPUT_H);

	function _mouseIn(bx:Float, by:Float, bw:Float, bh:Float):Bool
	{
		var mx = FlxG.mouse.x;
		var my = FlxG.mouse.y;
		return mx >= bx && mx <= bx + bw && my >= by && my <= by + bh;
	}

	function _moveAll(nx:Float, ny:Float):Void
	{
		var dx = nx - _panelX;
		var dy = ny - _panelY;
		if (dx == 0 && dy == 0) return;
		_panelX = nx;
		_panelY = ny;
		forEach(function(m:flixel.FlxBasic)
		{
			var o = cast(m, flixel.FlxObject);
			o.x += dx;
			o.y += dy;
		});
	}

	function _spr(x:Float, y:Float, w:Float, h:Float, color:Int):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(Std.int(w), Std.int(h), FlxColor.fromInt(color));
		return s;
	}

	function _txt(x:Float, y:Float, w:Float, text:String, size:Int, color:FlxColor):FlxText
	{
		var t = new FlxText(x, y, Std.int(w), text);
		t.setFormat(null, size, color, LEFT);
		return t;
	}
}
