///|
fn main {
  @ui.start_motion()
  @ui.start_scrollspy()
  @rabbita.new(@ui.app).mount("app")
}
