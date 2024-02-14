# About

# High

- Found a Dos in line 89

# Informational

`PuppyRaffle::entranceFee` is immutable, and should be like `i_entranceFee`.

---

`selectWinner()`

- Since it is an external function. Anyone can call it.
- q do we want any one to call this fn?

- q does it follow CEI?

- q does `raffleStartTime` gets updated after each raffle draw?
- q does `raffleDuration` is set correctly?

- 