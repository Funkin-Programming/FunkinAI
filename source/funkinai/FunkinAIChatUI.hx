package funkinai;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkinai.FunkinAI;
import funkinai.FunkinAIConfig;

/**
 * FunkinAI - Chat Overlay UI
 * A HaxeFlixel overlay group that renders the FunkinAI chat window.
 * 
 * Usage in any FlxState:
 *   var chatUI = new FunkinAIChatUI();
 *   add(chatUI);
 * 
 * Then in update():
 *   chatUI.update(elapsed);
 *   (FlxGroup handles this automatically if added to state)
 */
class FunkinAIChatUI extends FlxGroup
{
	// ─── Layout Constants ────────────────────────────────────────────────────

	static inline var PANEL_W:Float    = 500;
	static inline var PANEL_H:Float    = 360;
	static inline var PADDING:Float    = 12;
	static inline var INPUT_H:Float    = 36;
	static inline var MSG_FONT_SIZE:Int = 13;
	static inline var TITLE_FONT_SIZE:Int = 16;
	static inline var TOGGLE_KEY = flixel.input.keyboard.FlxKey.TAB;

	// ─── UI Elements ─────────────────────────────────────────────────────────

	var panel:FlxSprite;
	var titleBar:FlxSprite;
	var titleText:FlxText;
	var closeBtn:FlxText;

	var messageArea:FlxSprite;
	var messageTexts:Array<FlxText> = [];

	var inputBox:FlxSprite;
	var inputText:FlxText;
	var sendBtn:FlxSprite;
	var sendBtnLabel:FlxText;
	var thinkingDots:FlxText;

	var inputBuffer:String = "";
	var isVisible:Bool = false;
	var isDragging:Bool = false;
	var dragOffsetX:Float = 0;
	var dragOffsetY:Float = 0;

	/** The AI backend */
	var ai:FunkinAI;

	/** Display messages — {role, text} */
	var displayMessages:Array<{role:String, text:String}> = [];

	// ─── Constructor ─────────────────────────────────────────────────────────

	public function new()
	{
		super();

		ai = new FunkinAI();
		ai.onResponse = _onResponse;
		ai.onError    = _onError;
		ai.onThinking = _onThinking;

		_buildUI();
		setVisible(false);
	}

	// ─── Update ──────────────────────────────────────────────────────────────

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		// Tick the AI (dispatches pending callbacks on sys targets)
		ai.update();

		// Toggle chat with TAB
		if (FlxG.keys.justPressed.TAB)
			setVisible(!isVisible);

		if (!isVisible)
			return;

		_handleKeyboardInput(elapsed);
		_handleDragging();
		_animateThinkingDots(elapsed);
	}

	// ─── Public ──────────────────────────────────────────────────────────────

	public function setVisible(v:Bool):Void
	{
		isVisible = v;
		forEach(function(m) m.visible = v);

		if (v)
		{
			// Slide in from right
			panel.x = FlxG.width;
			var targetX = (FlxG.width - PANEL_W) / 2;
			FlxTween.tween(panel, {x: targetX}, 0.25, {ease: FlxEase.expoOut});
		}
	}

	// ─── UI Builder ──────────────────────────────────────────────────────────

	function _buildUI():Void
	{
		var px = (FlxG.width  - PANEL_W) / 2;
		var py = (FlxG.height - PANEL_H) / 2;

		// ── Background panel ──────────────────────────────────────────────
		panel = _makeRect(px, py, PANEL_W, PANEL_H, FlxColor.fromRGB(15, 15, 25, 230));
		add(panel);

		// ── Title bar ─────────────────────────────────────────────────────
		titleBar = _makeRect(px, py, PANEL_W, 32, FlxColor.fromRGB(255, 80, 130, 255));
		add(titleBar);

		titleText = new FlxText(px + PADDING, py + 6, PANEL_W - 60, "🎵 FunkinAI");
		titleText.setFormat(null, TITLE_FONT_SIZE, FlxColor.WHITE, LEFT);
		titleText.setBorderStyle(SHADOW, FlxColor.fromRGB(0, 0, 0, 120), 1);
		add(titleText);

		closeBtn = new FlxText(px + PANEL_W - 36, py + 6, 30, "✕");
		closeBtn.setFormat(null, TITLE_FONT_SIZE, FlxColor.WHITE, CENTER);
		add(closeBtn);

		// ── Message area ──────────────────────────────────────────────────
		var msgAreaY = py + 32 + PADDING;
		var msgAreaH = PANEL_H - 32 - INPUT_H - PADDING * 3 - 8;
		messageArea = _makeRect(px + PADDING, msgAreaY, PANEL_W - PADDING * 2, msgAreaH,
			FlxColor.fromRGB(8, 8, 18, 200));
		add(messageArea);

		// Pre-create message text slots
		for (i in 0...FunkinAIConfig.MAX_VISIBLE_MESSAGES)
		{
			var mt = new FlxText(px + PADDING + 6, msgAreaY + 6 + i * 38, PANEL_W - PADDING * 2 - 12, "");
			mt.setFormat(null, MSG_FONT_SIZE, FlxColor.WHITE, LEFT);
			mt.wordWrap = true;
			messageTexts.push(mt);
			add(mt);
		}

		// ── Input box ─────────────────────────────────────────────────────
		var inputY = py + PANEL_H - INPUT_H - PADDING;
		inputBox = _makeRect(px + PADDING, inputY, PANEL_W - PADDING * 2 - 70, INPUT_H,
			FlxColor.fromRGB(30, 30, 50, 255));
		add(inputBox);

		inputText = new FlxText(px + PADDING + 6, inputY + 10, PANEL_W - PADDING * 2 - 82, "");
		inputText.setFormat(null, MSG_FONT_SIZE, FlxColor.fromRGB(220, 220, 255), LEFT);
		add(inputText);

		// ── Send button ───────────────────────────────────────────────────
		sendBtn = _makeRect(px + PANEL_W - PADDING - 62, inputY, 62, INPUT_H,
			FlxColor.fromRGB(255, 80, 130, 255));
		add(sendBtn);

		sendBtnLabel = new FlxText(px + PANEL_W - PADDING - 62, inputY + 10, 62, "Send");
		sendBtnLabel.setFormat(null, MSG_FONT_SIZE, FlxColor.WHITE, CENTER);
		add(sendBtnLabel);

		// ── Thinking dots ─────────────────────────────────────────────────
		thinkingDots = new FlxText(px + PANEL_W - PADDING - 62, msgAreaY + 6, 60, "");
		thinkingDots.setFormat(null, 20, FlxColor.fromRGB(255, 80, 130), CENTER);
		thinkingDots.visible = false;
		add(thinkingDots);

		// ── Welcome message ───────────────────────────────────────────────
		_pushMessage("ai", "Yo! I'm FunkinAI 🎵 Ask me anything about FNF!");
	}

	// ─── Input Handling ──────────────────────────────────────────────────────

	function _handleKeyboardInput(elapsed:Float):Void
	{
		// Click on close button
		if (FlxG.mouse.justPressed)
		{
			if (_hitsCloseBtn())
			{
				setVisible(false);
				return;
			}
			if (_hitsSendBtn() && !ai.isBusy)
			{
				_submitInput();
				return;
			}
		}

		if (ai.isBusy)
			return;

		// Type characters
		var typed = FlxG.keys.firstJustPressed();
		if (typed != NONE)
		{
			var char = _keyToChar(typed, FlxG.keys.pressed.SHIFT);
			if (char != null && inputBuffer.length < FunkinAIConfig.MAX_INPUT_LENGTH)
				inputBuffer += char;
		}

		// Backspace
		if (FlxG.keys.justPressed.BACKSPACE && inputBuffer.length > 0)
			inputBuffer = inputBuffer.substr(0, inputBuffer.length - 1);

		// Enter to send
		if (FlxG.keys.justPressed.ENTER)
			_submitInput();

		// Update input display with blinking cursor
		var cursor = (Math.floor(FlxG.game.ticks / 500) % 2 == 0) ? "|" : "";
		inputText.text = inputBuffer + cursor;
	}

	function _handleDragging():Void
	{
		// Drag by title bar
		if (FlxG.mouse.justPressed && _hitsTitleBar())
		{
			isDragging = true;
			dragOffsetX = FlxG.mouse.x - panel.x;
			dragOffsetY = FlxG.mouse.y - panel.y;
		}

		if (FlxG.mouse.released)
			isDragging = false;

		if (isDragging)
		{
			var newX = FlxG.mouse.x - dragOffsetX;
			var newY = FlxG.mouse.y - dragOffsetY;
			// Clamp to screen
			newX = Math.max(0, Math.min(FlxG.width  - PANEL_W, newX));
			newY = Math.max(0, Math.min(FlxG.height - PANEL_H, newY));
			_movePanel(newX, newY);
		}
	}

	var _dotTimer:Float = 0;
	var _dotCount:Int = 0;

	function _animateThinkingDots(elapsed:Float):Void
	{
		if (!thinkingDots.visible) return;
		_dotTimer += elapsed;
		if (_dotTimer >= 0.4)
		{
			_dotTimer = 0;
			_dotCount = (_dotCount + 1) % 4;
			var dots = "";
			for (i in 0..._dotCount) dots += "•";
			thinkingDots.text = dots;
		}
	}

	function _submitInput():Void
	{
		var msg = StringTools.trim(inputBuffer);
		if (msg.length == 0 || ai.isBusy)
			return;

		_pushMessage("user", msg);
		inputBuffer = "";
		inputText.text = "";

		ai.send(msg);
	}

	// ─── AI Callbacks ────────────────────────────────────────────────────────

	function _onThinking():Void
	{
		thinkingDots.visible = true;
		thinkingDots.text = "•";
		_dotTimer = 0;
		_dotCount = 1;
	}

	function _onResponse(text:String):Void
	{
		thinkingDots.visible = false;
		_pushMessage("ai", text);
	}

	function _onError(err:String):Void
	{
		thinkingDots.visible = false;
		_pushMessage("ai", "⚠️ Oops! Couldn't reach the API. Check your key.");
		trace("[FunkinAI] Error: " + err);
	}

	// ─── Message Display ─────────────────────────────────────────────────────

	function _pushMessage(role:String, text:String):Void
	{
		displayMessages.push({role: role, text: text});
		_refreshMessages();
	}

	function _refreshMessages():Void
	{
		var visible = displayMessages.slice(-FunkinAIConfig.MAX_VISIBLE_MESSAGES);

		for (i in 0...messageTexts.length)
		{
			var mt = messageTexts[i];
			if (i < visible.length)
			{
				var msg = visible[i];
				var prefix = (msg.role == "user") ? "> " : "AI: ";
				mt.text  = prefix + msg.text;
				mt.color = (msg.role == "user")
					? FlxColor.fromRGB(180, 255, 180)
					: FlxColor.fromRGB(255, 200, 230);
				mt.visible = true;
			}
			else
			{
				mt.text    = "";
				mt.visible = false;
			}
		}
	}

	// ─── Panel Movement ──────────────────────────────────────────────────────

	function _movePanel(nx:Float, ny:Float):Void
	{
		var dx = nx - panel.x;
		var dy = ny - panel.y;
		forEach(function(m) { m.x += dx; m.y += dy; });
	}

	// ─── Hit Tests ───────────────────────────────────────────────────────────

	function _hitsTitleBar():Bool
		return FlxG.mouse.x >= titleBar.x && FlxG.mouse.x <= titleBar.x + PANEL_W
			&& FlxG.mouse.y >= titleBar.y && FlxG.mouse.y <= titleBar.y + 32;

	function _hitsCloseBtn():Bool
		return FlxG.mouse.x >= closeBtn.x && FlxG.mouse.x <= closeBtn.x + 30
			&& FlxG.mouse.y >= closeBtn.y && FlxG.mouse.y <= closeBtn.y + 24;

	function _hitsSendBtn():Bool
		return FlxG.mouse.x >= sendBtn.x && FlxG.mouse.x <= sendBtn.x + 62
			&& FlxG.mouse.y >= sendBtn.y && FlxG.mouse.y <= sendBtn.y + INPUT_H;

	// ─── Helpers ─────────────────────────────────────────────────────────────

	function _makeRect(x:Float, y:Float, w:Float, h:Float, color:FlxColor):FlxSprite
	{
		var s = new FlxSprite(x, y);
		s.makeGraphic(Std.int(w), Std.int(h), color);
		return s;
	}

	/**
	 * Converts a FlxKey to its character string, respecting Shift.
	 * Only covers the keys needed for chat input.
	 */
	function _keyToChar(key:flixel.input.keyboard.FlxKey, shift:Bool):Null<String>
	{
		var k = Std.string(key);

		// Letters
		if (k.length == 1 && k >= "A" && k <= "Z")
			return shift ? k : k.toLowerCase();

		// Numbers
		if (!shift) switch (k) {
			case "ZERO": return "0"; case "ONE": return "1";
			case "TWO": return "2"; case "THREE": return "3";
			case "FOUR": return "4"; case "FIVE": return "5";
			case "SIX": return "6"; case "SEVEN": return "7";
			case "EIGHT": return "8"; case "NINE": return "9";
		}

		// Symbols
		switch (k)
		{
			case "SPACE":       return " ";
			case "PERIOD":      return shift ? ">" : ".";
			case "COMMA":       return shift ? "<" : ",";
			case "SLASH":       return shift ? "?" : "/";
			case "QUOTE":       return shift ? "\"" : "'";
			case "SEMICOLON":   return shift ? ":" : ";";
			case "MINUS":       return shift ? "_" : "-";
			case "PLUS":        return shift ? "+" : "=";
			case "EXCLAMATION": return "!";
			default:            return null;
		}
	}
}
