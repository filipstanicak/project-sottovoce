## **WHETHER THIS PROCESS HAS A SCREEN.** ADR-0026. CLIENT ONLY.
##
## A bot is a headless client, `play.bat` starts three to five of them, and so is
## every test that boots a client. None of them has a screen, so none of them is
## made to assemble a district or to animate ninety figures for one: dressing the
## booted test clients alone measured as 37 s on the integration suite.
##
## **ONE QUESTION, ASKED IN ONE PLACE**, so the art pass cannot half-run: a client
## that built the district and did not animate the crowd in it would be a third
## kind of client nobody tests.
class_name DisplayGate
extends RefCounted

## A test that wants the real boot path drawn sets this, and puts it back.
static var forced := false


static func draws() -> bool:
	return forced or DisplayServer.get_name() != "headless"
