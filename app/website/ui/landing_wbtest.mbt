///|
test "speed axis rounds up to an integer" {
  assert_eq(speed_axis_limit(4.163), 5.0)
  assert_eq(speed_axis_limit(4.5), 5.0)
  assert_eq(speed_axis_limit(4.0), 4.0)
  assert_eq(speed_axis_limit(0.0), 0.0)
}
