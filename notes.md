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

- In line `153` there is a potential overflow
- type(uint64).max = 18446744073709551615
- If 100 players entered the raffle by paying 1ETH each.
- Total value will be 100 ether
- owner will 20% cut which is 20 ether
- Storing 20 ether in uint64 max will cause overflow.
-
- Write POC for it. (Review)

---

- In line `153` there is a potential typecasting error
- when typecasted from `uint256` to `uint64` precisions will be lost
- This is unsafe typecasting
-
- write POC for it.

---

- Check line `179`

---

- Mishandling of ETH line `193`
- `address(this).balance` can be manipulated using `selfDestruct`
- Write Poc

---

- `_isActivePlayer` is not used anywhere in the contract
- Add this to findings as informational

---

- Unnecessary Emit in line `94`

---

- line `120`
