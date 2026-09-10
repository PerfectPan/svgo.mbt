///|
fn main {
  @ui.start_motion()
  @ui.start_video_lazyload()
  @rabbita.new(@ui.app).mount("app")
}
