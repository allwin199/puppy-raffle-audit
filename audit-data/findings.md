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

1. Consider allwing duplicates. Users can make new wallet addresses anyways, so a duplicate check dosen't prevent the same person from entering multiple times, only the same wallet address.

2. Consider using a mapping to check for duplicates. This would allow constant time lookup of whether a user has already entered.

```diff
+   mapping(address => uint256) public s_addressToRaffleId;
+   uint256 public raffleId = 0;
.
.
.
    function enterRaffle(address[] memory newPlayers) public payable {
        require(msg.value == entranceFee * newPlayers.length, "PuppyRaffle: Must send enough to enter raffle");
        for (uint256 i = 0; i < newPlayers.length; i++) {
            players.push(newPlayers[i]);
            addressToRaffleId[newPlayers[i]] = raffleId;
        }

-       // check for duplicates
-       for (uint256 i = 0; i < players.length - 1; i++) {
-            for (uint256 j = i + 1; j < players.length; j++) {
-               require(players[i] != players[j], "PuppyRaffle: Duplicate player");
-           }
-       }
+       // Check for duplicates only from the new players
+       for (uint256 i = 0; i < players.length; i++) { 
+            require(s_addressToRaffleId[i] != raffleId, "PuppyRaffle: Duplicate player");
+       }
    }

    function selectWinner() external {
+       raffleId = raffleId + 1;
        require(block.timestamp >= raffleStartTime + raffleDuration, "PuppyRaffle: Raffle not over");
    }
```