package funkinai;

/**
 * FunkinAI - Configuration
 * Central config for API credentials, model settings, and the system prompt.
 * 
 * IMPORTANT: Never hardcode your API key in source code for public repos.
 * Use a build flag: -D FUNKINAI_KEY=sk-ant-... in your Project.xml.
 */
class FunkinAIConfig
{
	// ─── API Settings ────────────────────────────────────────────────────────

	/** Anthropic API endpoint */
	public static inline var API_URL:String = "https://api.anthropic.com/v1/messages";

	/** Anthropic API version header */
	public static inline var API_VERSION:String = "2023-06-01";

	/** Model to use — claude-sonnet-4-20250514 recommended for speed+quality */
	public static inline var MODEL:String = "claude-sonnet-4-20250514";

	/** Max tokens in each response */
	public static inline var MAX_TOKENS:Int = 512;

	/**
	 * Your Anthropic API key.
	 * Set via build flag in Project.xml:
	 *   <haxedef name="FUNKINAI_KEY" value="sk-ant-xxxxxxxx" />
	 * Or replace the fallback string below for local testing only.
	 */
	public static var API_KEY(get, never):String;

	static function get_API_KEY():String
	{
		#if FUNKINAI_KEY
		return macro $v{haxe.macro.Context.definedValue("FUNKINAI_KEY")};
		#else
		return "YOUR_API_KEY_HERE"; // fallback — replace or set build flag
		#end
	}

	// ─── UI Settings ─────────────────────────────────────────────────────────

	/** How many chat messages to show in the UI at once */
	public static inline var MAX_VISIBLE_MESSAGES:Int = 6;

	/** Character limit per user message */
	public static inline var MAX_INPUT_LENGTH:Int = 200;

	/** How many messages to keep in conversation history sent to the API */
	public static inline var MAX_HISTORY_MESSAGES:Int = 10;

	// ─── System Prompt ───────────────────────────────────────────────────────

	/**
	 * The system prompt that defines FunkinAI's personality and knowledge scope.
	 * Tweak this freely to adjust tone, focus, or add engine-specific knowledge.
	 */
	public static inline var SYSTEM_PROMPT:String = "
You are FunkinAI, an AI assistant specialized in Friday Night Funkin' (FNF).
You are knowledgeable, friendly, and passionate about everything FNF-related.

Your areas of expertise:
- FNF lore, characters, story, and weeks (Boyfriend, Girlfriend, Daddy Dearest, Pico, etc.)
- Mods: popular mods like Vs. Sonic.exe, Indie Cross, Bob's Onslaught, Dave & Bambi, etc.
- Fan engines: Psych Engine, Kade Engine, Codename Engine, Forever Engine, Mic'd Up, etc.
- Chart/note mechanics, difficulty systems, and gameplay concepts
- HaxeFlixel and Haxe development for FNF engines
- The FNF community, history, and development

Rules:
- Keep answers concise — this is an in-game overlay, not an essay.
- If asked about something outside FNF, politely redirect to FNF topics.
- You can discuss adult mods in general terms but avoid explicit content.
- Speak naturally and casually, like a fellow FNF fan.
- Use game terminology correctly (week, chart, BF, GF, instakill, etc.)
";
}
