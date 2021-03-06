#if nme
class NMESimpleAudioEngine {
	
#if android
	
	
    
#elseif (ios || mac)
	
	public static function preloadBackgroundMusic (filePath:String) {
		ralcr_preload_background_music ( filePath );
	}
	public static function playBackgroundMusic (filePath:String, loop:Bool) {
		ralcr_play_background_music (filePath, loop);
	}
	public static function stopBackgroundMusic () {
		ralcr_stop_background_music();
	}
	public static function pauseBackgroundMusic () {
		ralcr_pause_background_music();
	}
	public static function resumeBackgroundMusic () {
		ralcr_resume_background_music();
	}
	public static function rewindBackgroundMusic () {
		ralcr_rewind_background_music();
	}
	public static function isBackgroundMusicPlaying () :Bool {
		return ralcr_is_background_music_playing();
	}
	public static function playEffect (filePath:String, ?loop:Bool=false) :Int {
		return ralcr_play_effect ( filePath, loop );
	}
	public static function stopEffect (soundId:Int) {
		ralcr_stop_effect ( soundId );
	}
	public static function preloadEffect (filePath:String) {
		ralcr_preload_effect (filePath);
	}
	public static function unloadEffect (filePath:String) {
		ralcr_unload_effect (filePath);
	}
    
	static var ralcr_preload_background_music = nme.Loader.load("ralcr_preload_background_music", 1);
	static var ralcr_play_background_music = nme.Loader.load("ralcr_play_background_music", 2);
	static var ralcr_stop_background_music = nme.Loader.load("ralcr_stop_background_music", 0);
	static var ralcr_pause_background_music = nme.Loader.load("ralcr_pause_background_music", 0);
	static var ralcr_resume_background_music = nme.Loader.load("ralcr_resume_background_music", 0);
	static var ralcr_rewind_background_music = nme.Loader.load("ralcr_rewind_background_music", 0);
	static var ralcr_is_background_music_playing = nme.Loader.load("ralcr_is_background_music_playing", 0);
	static var ralcr_play_effect = nme.Loader.load("ralcr_play_effect", 2);
	static var ralcr_stop_effect = nme.Loader.load("ralcr_stop_effect", 1);
	static var ralcr_preload_effect = nme.Loader.load("ralcr_preload_effect", 1);
	static var ralcr_unload_effect = nme.Loader.load("ralcr_unload_effect", 1);
#end
}
#end