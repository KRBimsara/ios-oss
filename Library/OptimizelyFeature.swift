import Foundation

public enum OptimizelyFeature {
  public enum Key: String {
    case commentFlaggingEnabled = "ios_comment_threading_comment_flagging"
    case commentThreading = "ios_comment_threading"
    case commentThreadingRepliesEnabled = "ios_comment_threading_reply_buttons"
  }
}
