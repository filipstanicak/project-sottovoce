## **ONE NOTICE AT A TIME, FOR ITS DURATION, AND NONE LOST.** US-0105,
## UI_UX_SPEC §1.1 I. `NoticeVm` is the clock and the queue; `NoticeWidget` can only
## draw one of two string-table sentences.
extends GutTest

const PURSUER := NoticeWire.Kind.NEW_PURSUER
const LEAD := NoticeWire.Kind.TOOK_LEAD


func _duration() -> float:
	return float(Tuning.ui_audio.notice_duration)


func test_a_notice_shows_for_its_duration_and_no_longer() -> void:
	var vm := NoticeVm.new()
	vm.push(PURSUER)
	assert_eq(vm.current(), PURSUER, "the notice did not come up")
	vm.advance(_duration() - 0.1)
	assert_eq(vm.current(), PURSUER, "the notice left early")
	vm.advance(0.2)
	assert_eq(vm.current(), NoticeVm.NONE, "the notice outstayed its duration")


func test_a_second_notice_waits_for_the_first() -> void:
	var vm := NoticeVm.new()
	vm.push(PURSUER)
	vm.push(LEAD)
	assert_eq(vm.current(), PURSUER, "the second notice replaced the first")
	vm.advance(_duration() + 0.01)
	assert_eq(vm.current(), LEAD, "the second notice was lost")


func test_the_same_notice_again_restarts_rather_than_queues() -> void:
	var vm := NoticeVm.new()
	vm.push(PURSUER)
	vm.advance(_duration() * 0.8)
	vm.push(PURSUER)
	vm.advance(_duration() * 0.8)
	assert_eq(vm.current(), PURSUER, "a repeat did not restart the notice")
	vm.advance(_duration())
	assert_eq(vm.current(), NoticeVm.NONE, "a repeat was queued as a second copy")


func test_the_widget_says_only_its_two_sentences() -> void:
	var pursuer := Strings.get_text(&"ui.notice.new_pursuer")
	var lead := Strings.get_text(&"ui.notice.took_lead")
	assert_ne(pursuer, lead)
	for kind: int in [-1, NoticeVm.NONE, 0, 1, 2, 255]:
		assert_has(["", pursuer, lead], NoticeWidget.text_for(kind), "%d drew a sentence" % kind)
	assert_eq(NoticeWidget.text_for(PURSUER), pursuer)
	assert_eq(NoticeWidget.text_for(LEAD), lead)


func test_an_unknown_kind_off_the_wire_is_dropped() -> void:
	assert_true(NoticeWire.is_known(PURSUER))
	assert_true(NoticeWire.is_known(LEAD))
	assert_false(NoticeWire.is_known(NoticeWire.Kind.size()), "a newer server's kind was drawn")
	assert_false(NoticeWire.is_known(-1))
