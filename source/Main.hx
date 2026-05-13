package;

import flixel.FlxGame;
import flixel.FlxG;
import openfl.display.Sprite;
import openfl.display.StageScaleMode;
import openfl.display.StageAlign;
import openfl.display.StageQuality;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.Lib;

#if desktop
import sys.io.File;
import sys.FileSystem;
#end

class Main extends Sprite
{
	static inline var GAME_WIDTH:Int    = 1280;
	static inline var GAME_HEIGHT:Int   = 720;
	static inline var INITIAL_STATE:Class<flixel.FlxState> = funkinai.states.InitState;
	static inline var FRAMERATE:Int     = 60;
	static inline var SKIP_SPLASH:Bool  = true;
	static inline var START_FULLSCREEN:Bool = false;

	public function new()
	{
		super();

		if (stage != null)
			_init();
		else
			addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
	}

	function _onAddedToStage(e:Event):Void
	{
		removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
		_init();
	}

	function _init():Void
	{
		stage.scaleMode   = StageScaleMode.NO_SCALE;
		stage.align       = StageAlign.TOP_LEFT;
		stage.quality     = StageQuality.LOW;
		stage.frameRate   = FRAMERATE;
		stage.color       = 0xFF000000;

		_setupCrashHandler();
		_setupGame();
	}

	function _setupGame():Void
	{
		var game = new FlxGame(
			GAME_WIDTH,
			GAME_HEIGHT,
			INITIAL_STATE,
			FRAMERATE,
			FRAMERATE,
			SKIP_SPLASH,
			START_FULLSCREEN
		);

		#if mobile
		game.scaleMode = new flixel.util.FlxScaleMode();
		#end

		addChild(game);

		FlxG.fixedTimestep    = false;
		FlxG.autoPause        = false;
		FlxG.mouse.useSystemCursor = true;

		#if mobile
		FlxG.mouse.visible    = false;
		#end

		#if !mobile
		FlxG.fullscreen       = START_FULLSCREEN;
		#end
	}

	function _setupCrashHandler():Void
	{
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(
			UncaughtErrorEvent.UNCAUGHT_ERROR,
			_onUncaughtError
		);

		#if cpp
		untyped __global__.__hxcpp_set_critical_error_handler(_onCriticalError);
		#end
	}

	function _onUncaughtError(e:UncaughtErrorEvent):Void
	{
		e.preventDefault();
		e.stopImmediatePropagation();

		var msg = Std.string(e.error);
		_writeCrashLog("UncaughtError", msg);
		_showCrashScreen(msg);
	}

	#if cpp
	function _onCriticalError(msg:String):Void
	{
		_writeCrashLog("CriticalError", msg);
		_showCrashScreen(msg);
	}
	#end

	function _writeCrashLog(type:String, msg:String):Void
	{
		#if desktop
		try
		{
			var dir = "logs";
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);

			var stamp = DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S");
			var path  = '$dir/crash_${stamp}.txt';
			var content = '[FunkinAI $type]\n$msg\n\nHaxe: ${haxe.macro.Compiler.getDefine("haxe")}\n';
			File.saveContent(path, content);
		}
		catch (_:Dynamic) {}
		#end
	}

	function _showCrashScreen(msg:String):Void
	{
		try
		{
			if (FlxG.game != null)
				FlxG.switchState(new funkinai.states.CrashState(msg));
		}
		catch (_:Dynamic)
		{
			Lib.application.window.close();
		}
	}

	static public function main():Void
	{
		#if android
		lime.system.System.allowScreenTimeout = false;
		#end

		Lib.current.addChild(new Main());
	}
}
