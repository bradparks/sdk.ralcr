
typedef FacebookFriend = {
	var name : String;
	var id : String;
}
typedef FacebookFriendPhoto = {
	var url : String;
	var is_silhouette : Bool;
}


class FacebookTools {
	
	/**
	*  @param func - should be of type Dynamic->Dynamic->Void
	*/
	public static function requestInfoForUserId (userId:String, func:Dynamic->Dynamic->Void) {
		Facebook.sharedFacebook().api (userId, func, null, "GET");
	}
	
	/**
	*  Returns in func an Array<FacebookFriend>
	*/
	public static function requestFriends (func:Dynamic->Dynamic->Void) {
		Facebook.sharedFacebook().api ("me/friends", func, null, "GET");
	}
	
	/**
	*  Returns in func a FacebookFriendPhoto
	*/
	public static function requestProfilePictureForUserId (userId:String, func:Dynamic->Dynamic->Void) {
		Facebook.sharedFacebook().api (userId + "/picture?type=large&redirect=0&", func, null, "GET");
	}
	
	/**
	*  Returns an Object containing an 'id'
	*/
    public static function postData (method:String, func:Dynamic->Dynamic->Void, params:Dynamic) {
		Facebook.sharedFacebook().api (method, func, params, "POST");
    }
	
    /**
     * Utility method to format a picture URL, in order to load an image from Facebook.
     *
     * @param id The ID you wish to load an image from.
     * @param type The size of image to display from Facebook
     * (square, small, or large).
     *
     * @see http://developers.facebook.com/docs/api#pictures
     *
     */
    public function buildImageURLWithId (id:String, ?type:String) :String {
        return Facebook.GRAPH_URL + '/' + id + '/picture' + (type != null ? ('?type=' + type) : '');
    }
}
