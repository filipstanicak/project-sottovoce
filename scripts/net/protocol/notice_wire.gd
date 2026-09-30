## **THE ONE-LINE NOTICES, ON THE WIRE.** `NET-S2C-NOTICE`, US-0105, ADR-0024.
##
## The reference tells a player, in one line, that *a new pursuer is on them* and
## that *they have taken the lead*. The message carries which of those it is and
## **nothing else**: no slot, no name, no score. Who the pursuer is and who was
## overtaken are exactly the facts the crowd exists to hide.
##
## **THE ORDER IS THE WIRE AND IT IS APPEND-ONLY**, like every enum carried as a
## byte here: a kind inserted in the middle would tell every older client a
## different notice, plausibly and in silence.
class_name NoticeWire
extends RefCounted

enum Kind { NEW_PURSUER, TOOK_LEAD }


## Whether a byte off the wire names a notice this build knows. A newer server's
## kind is dropped rather than drawn as the wrong sentence.
static func is_known(kind: int) -> bool:
	return kind >= 0 and kind < Kind.size()
