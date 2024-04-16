pragma solidity >=0.7.0 <0.9.0;

/*
 *  Idea - YES/NO is a one-side-wins-it-all voting game.
 *
 *  There are two sides, YES, and NO. You pick which one you want and cast
 *  a vote for the corresponding side. Each poll runs for some specified amount
 *  of time - this can be done daily or weekly by the contract owner.
 *
 *  The voting ends after the specified interval and people who have bet on the
 *  winning side are paid out per the following math:
 *
 *  u0 = user's bet on the winning team
 *  w = winning total bets
 *  l = losing total bets (l < w!)
 *
 */
// SPDX-License-Identifier: MIT

/******************************************************************************/

/*
 *  SafeMath lib borrowed from:
 *  https://github.com/OpenZeppelin/openzeppelin-contracts/commit/0b489f4d79544ab9b870abe121077043feb971b8
 */
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "+ oflw");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "- oflw");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "* oflw");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "/ 0");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "% 0");
    }

    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/******************************************************************************/

// Main contract for the Yes/No voting game
contract YesNo {
    using SafeMath for uint256; // Using SafeMath library for uint256 type

    // uint256 constant BLOCK_DIV = 4096; // Number of blocks per game
    uint256 pollEndTime;
    enum VoteType {
        VOTE_YES,
        VOTE_NO
    } // Enumeration for vote types

    // Struct to represent a vote
    struct Vote {
        uint256 game_id; // ID of the game (block number divided by BLOCK_DIV)
        uint256 amount; // Amount of credits bet
        VoteType vote_type; // Type of vote (Yes or No)
    }

    // Struct to represent poll totals for a game
    struct Poll {
        uint256 yes_total; // Total credits bet for Yes
        uint256 no_total; // Total credits bet for No
        uint256 yes_count; // Number of Yes votes
        uint256 no_count; // Number of No votes
    }

    // Struct to represent a voter
    struct Voter {
        mapping(uint256 => Vote[]) votes; // Mapping of game IDs to votes
        mapping(uint256 => bool) claimed; // Mapping of game IDs to claimed status
        uint256 credits; // Credits balance of the voter
    }

    mapping(address => Voter) private voters; // Mapping of addresses to voters
    mapping(uint256 => Poll) private poll_totals; // Mapping of game IDs to poll totals

    event NewVoteCast(); // Event emitted when a new vote is cast

    address public owner_address; // Address of the contract owner

    // Constructor function to initialize the contract
    constructor(uint256 _seconds) {
        owner_address = msg.sender; // Set the contract owner address
        setPollEndTime(_seconds);
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner_address,
            "Only the contract owner can call this function"
        );
        _;
    }

    // Function for users to buy credits by sending ether
    function BuyCredits() public payable {
        voters[msg.sender].credits = voters[msg.sender].credits.add(msg.value);
    }

    // Function for users to withdraw credits
    function WithdrawCredits(uint256 amount) public {
        require(amount <= voters[msg.sender].credits, "Insufficient credits");
        voters[msg.sender].credits = voters[msg.sender].credits.sub(amount);
        payable(msg.sender).transfer(amount);
    }

    // Function to get the credit balance of a user
    function GetCreditBalance() public view returns (uint256) {
        return voters[msg.sender].credits;
    }

    // Function to get the current game ID
    // function GetCurrentGame() public view returns (uint256) {
    //     return block.number / BLOCK_DIV;
    // }

    // Function to get the totals for a specific game
    function GetGameTotals()
        public
        view
        returns (uint256, uint256, uint256, uint256)
    {
        require(0 < (pollEndTime / block.timestamp), "Game not yet finished");
        return (
            poll_totals[0].yes_total,
            poll_totals[0].no_total,
            poll_totals[0].yes_count,
            poll_totals[0].no_count
        );
    }

    // Function to get the earnings of a user
    function GetEarnings() public view returns (uint256, uint256, bool) {
        uint game_id = pollEndTime / block.timestamp;
        require(block.timestamp / pollEndTime > 0, "No game has finished yet");

        uint256 earned = 0; // Round winnings
        uint256 spent = 0; // Spend counter
        bool claimed = voters[msg.sender].claimed[game_id]; // Check if earnings are claimed
        uint256 r = poll_totals[game_id].yes_total; // Total credits bet for Yes
        uint256 b = poll_totals[game_id].no_total; // Total credits bet for No

        for (uint256 i = 0; i < voters[msg.sender].votes[game_id].length; i++) {
            uint256 amt = voters[msg.sender].votes[game_id][i].amount;
            spent = spent.add(amt);

            if (r == b) {
                earned = earned.add(amt);
            } else if (
                voters[msg.sender].votes[game_id][i].vote_type ==
                VoteType.VOTE_YES &&
                r > b
            ) {
                earned = earned.add(((b.mul(amt)).div(r)));
                earned = earned.add(amt);
            } else if (
                voters[msg.sender].votes[game_id][i].vote_type ==
                VoteType.VOTE_NO &&
                b > r
            ) {
                earned = earned.add(((r.mul(amt)).div(b)));
                earned = earned.add(amt);
            }
        }

        return (earned, spent, claimed);
    }

    // Function for users to claim their earnings
    function ClaimEarnings(uint256 game_id) public {
        require(block.timestamp > pollEndTime, "Vote not yet finished.");

        uint256 earned;
        uint256 spent;
        bool claimed;
        (earned, spent, claimed) = GetEarnings();
        require(earned > 0 && spent > 0 && !claimed, "No earnings to claim");

        voters[msg.sender].claimed[game_id] = true;
        voters[msg.sender].credits = voters[msg.sender].credits.add(earned);
    }

    // Function for users to cast their votes
    function CastVote(uint256 amount, VoteType vote_type) public {
        require(amount > 0, "Amount must be greater than zero");
        require(amount <= voters[msg.sender].credits, "Insufficient credits");
        require(pollEndTime > block.timestamp, "Voting time has ended");

        uint256 gameID = block.timestamp / pollEndTime;

        Vote memory v;
        v.game_id = gameID;
        v.amount = amount;
        v.vote_type = vote_type;

        if (vote_type == VoteType.VOTE_YES) {
            poll_totals[gameID].yes_total = poll_totals[gameID].yes_total.add(
                amount
            );
            poll_totals[gameID].yes_count = poll_totals[gameID].yes_count.add(
                1
            );
        } else if (vote_type == VoteType.VOTE_NO) {
            poll_totals[gameID].no_total = poll_totals[gameID].no_total.add(
                amount
            );
            poll_totals[gameID].no_count = poll_totals[gameID].no_count.add(1);
        }

        voters[msg.sender].credits = voters[msg.sender].credits.sub(amount);
        voters[msg.sender].votes[gameID].push(v);
        emit NewVoteCast();
    }

    // Function to get the winner of the current game
    function GetWinner() public view returns (string memory) {
        uint256 current_game_id = block.timestamp / pollEndTime;
        // require(current_game_id > 0, "No game has finished yet");
        require(pollEndTime < block.timestamp, "No game has finished yet");

        uint256 yesTotal = poll_totals[current_game_id].yes_total;
        uint256 noTotal = poll_totals[current_game_id].no_total;

        if (yesTotal > noTotal) {
            return "YES";
        } else if (noTotal > yesTotal) {
            return "NO";
        } else {
            return "DRAW";
        }
    }

    // For the development purposes
    function GetCurrentRunningBlock()
        public
        view
        returns (uint256, uint256, uint256)
    {
        return (block.number, block.timestamp, block.number);
    }

    function setPollEndTime(uint256 _seconds) private onlyOwner {
        pollEndTime = (block.timestamp).add(_seconds); // 60 seconds for voting
    }

    // Function to set the end time for voting
    function checkPollEndTime() public view returns (uint256) {
        return pollEndTime;
    }
}

/******************************************************************************/
