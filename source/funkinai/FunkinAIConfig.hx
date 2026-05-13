package funkinai;

class FunkinAIConfig
{
	public static inline var API_URL:String            = "https://api.anthropic.com/v1/messages";
	public static inline var API_VERSION:String        = "2023-06-01";
	public static inline var MODEL:String              = "claude-sonnet-4-20250514";
	public static inline var MAX_TOKENS:Int            = 512;
	public static inline var MAX_HISTORY:Int           = 10;
	public static inline var MAX_INPUT_LENGTH:Int      = 200;
	public static inline var MAX_VISIBLE:Int           = 8;
	public static inline var TYPING_CPS:Float          = 45.0;
	public static inline var REQUEST_TIMEOUT:Float     = 30.0;
	public static inline var MAX_RETRIES:Int           = 2;
	public static inline var RETRY_DELAY:Float         = 1.5;
	public static inline var RATE_LIMIT_INTERVAL:Float = 0.5;

	public static var API_KEY:String = "";

	public static inline var C_USER:Int        = 0xFF90EE90;
	public static inline var C_AI:Int          = 0xFFFFB6C1;
	public static inline var C_SYSTEM:Int      = 0xFF7777AA;
	public static inline var C_PANEL:Int       = 0xF20A0A18;
	public static inline var C_TITLEBAR:Int    = 0xFFFF5082;
	public static inline var C_MSGAREA:Int     = 0xF2060610;
	public static inline var C_INPUT:Int       = 0xFF12122A;
	public static inline var C_SEND:Int        = 0xFFFF5082;
	public static inline var C_SEND_BUSY:Int   = 0xFF883355;
	public static inline var C_SCROLLBG:Int    = 0xFF1A1A30;
	public static inline var C_SCROLLTHUMB:Int = 0xFFFF5082;
	public static inline var C_PLACEHOLDER:Int = 0xFF444466;
	public static inline var C_STATUS_OK:Int   = 0xFFAAAAAA;
	public static inline var C_STATUS_ERR:Int  = 0xFFFF6666;
	public static inline var C_STATUS_WAIT:Int = 0xFFFFCC66;

	public static inline var TOGGLE_KEY = flixel.input.keyboard.FlxKey.TAB;

	public static inline var SYSTEM_PROMPT:String = "
You are FunkinAI, an AI assistant embedded inside a Friday Night Funkin' fan engine.
You are a knowledgeable, chill FNF fan who lives and breathes the game.

Core knowledge:
- FNF canon: Boyfriend (BF), Girlfriend (GF), Daddy Dearest, Mommy Mearest, Skid & Pump, Pico, Ayana, Nene, Darnell, Senpai, Spirit, Tankman, Henchmen
- Top mods: Vs. Sonic.exe, Indie Cross (Cuphead, Undertale, Bendy), Bob's Onslaught, Dave & Bambi, Tricky Mod, Whitty, Hex, Mid-Fight Masses, Sky Mod, VS Matt, Garcello, Agoti, Tabi, Carol, Trollge, Hecker, Zardy, Vs. Impostor, Friday Night Dustin
- Fan engines: Psych Engine, Kade Engine, Codename Engine, Forever Engine, Mic'd Up, Crow Engine, Base Game (vanilla), Ludum Dare build, Andromeda, V-Slice (official rewrite)
- Modding: Lua scripting, HaxeFlixel/Haxe, chart JSON format, events system, dialogue boxes, stages, character animations, health icons
- Charting tools: ArrowVortex (community standard), Psych chart editor, Kade editor, Bunny-Hop, FNF-to-SM converters
- Gameplay: notes, sustains, mines, BPM, song offset, health drain/gain, ghost tapping, botplay, full combo (FC), perfect, score ratings (Sick/Good/Bad/Shit), miss penalties
- Community: Newgrounds roots, original Game Jam build, PhantomArcade, evilsk8r, ninjamuffin99, KawaiSprite, Funkin Crew Inc., GameBanana, itch.io modding scene
- V-Slice rewrite: scripted characters, weeks replaced by story chapters, improved cutscene system, freeplay rework

Behavior:
- Be concise: 2-4 sentences max unless the user asks for more.
- Use FNF terms naturally. Never over-explain basic terms to a player.
- If asked anything not FNF-related, say: 'I only know FNF stuff! Ask me about the game, mods, or engines.'
- Never invent mod names, characters, or engines that do not exist.
- Be playful and use emojis occasionally.
";

	public static function loadApiKey():Void
	{
		#if sys
		var paths = ["funkinai.json", "data/funkinai.json", "assets/data/funkinai.json"];
		for (path in paths)
		{
			if (sys.FileSystem.exists(path))
			{
				try
				{
					var json:Dynamic = haxe.Json.parse(sys.io.File.getContent(path));
					if (json.apiKey != null && Std.string(json.apiKey).length > 8)
						API_KEY = Std.string(json.apiKey);
				}
				catch (_:Dynamic) {}
				return;
			}
		}
		#end
	}
}
