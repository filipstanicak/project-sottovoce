## **WHO HAS JUST TAKEN THE LEAD.** US-0105. `ScoreLead` is pure: totals in, a peer
## or nobody out.
extends GutTest

const A := 11
const B := 12
const C := 13


func test_the_sole_top_scorer_leads() -> void:
	assert_eq(ScoreLead.sole_leader({A: 300, B: 200}), A)


func test_a_shared_top_is_nobodys_lead() -> void:
	assert_eq(ScoreLead.sole_leader({A: 300, B: 300, C: 100}), ScoreLead.NOBODY)


func test_a_later_higher_score_breaks_an_earlier_tie() -> void:
	# The case a single pass gets wrong if a tie is remembered after being beaten.
	assert_eq(ScoreLead.sole_leader({A: 300, B: 300, C: 400}), C)


func test_nobody_leads_until_somebody_scores() -> void:
	assert_eq(ScoreLead.sole_leader({A: 0, B: 0}), ScoreLead.NOBODY)
	assert_eq(ScoreLead.sole_leader({A: 0, B: -50}), ScoreLead.NOBODY, "zero is not a lead")
	assert_eq(ScoreLead.sole_leader({}), ScoreLead.NOBODY)


func test_taking_the_lead_is_news_and_holding_it_is_not() -> void:
	var lead := ScoreLead.new()
	assert_eq(lead.taken_by({A: 100}), A, "the first scorer did not take the lead")
	assert_eq(lead.taken_by({A: 300, B: 100}), ScoreLead.NOBODY, "holding it was announced")
	assert_eq(lead.taken_by({A: 300, B: 400}), B, "overtaking was not announced")


func test_pulling_clear_after_being_caught_is_taking_it_again() -> void:
	var lead := ScoreLead.new()
	lead.taken_by({A: 300, B: 100})
	assert_eq(lead.taken_by({A: 300, B: 300}), ScoreLead.NOBODY, "a tie announced somebody")
	assert_eq(lead.taken_by({A: 400, B: 300}), A, "retaking the lead after a tie was silent")
