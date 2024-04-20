pragma solidity >=0.7.0 <0.9.0;
import "./Bank.sol";

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
        // know the credits available from the Bank Contract
        // uint256 credits; // Credits balance of the voter
    }

    mapping(address => Voter) private voters; // Mapping of addresses to voters
    mapping(uint256 => Poll) private poll_totals; // Mapping of game IDs to poll totals

    event NewVoteCast(); // Event emitted when a new vote is cast

    address public owner_address; // Address of the contract owner
    address private marketplace;
    address payable public bankContract;

    // Constructor function to initialize the contract
    constructor(
        uint256 _seconds,
        address _owner,
        address payable _bankAddress
    ) payable {
        require(msg.value >= 10 wei, "Minimum deposit of 10 wei required");
        owner_address = _owner; // Set the contract owner address
        marketplace = msg.sender;
        bankContract = _bankAddress;
        setPollEndTime(_seconds);
    }

    // Here after the necessary checks only the marketplace is the owner
    modifier onlyOwner() {
        require(
            msg.sender == owner_address,
            "Only the contract owner can call this function"
        );
        _;
    }

    modifier onlyMarketPlace() {
        require(
            msg.sender == marketplace,
            "Only marketplace can set the endTime"
        );
        _;
    }

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

    // Function to deposit funds into the Bank contract
    function depositFunds(address _depositor, uint256 amount) external payable {
        // Call the deposit function of the Bank contract
        Bank(bankContract).depositFromYesNo{value: amount}(
            _depositor,
            marketplace
        );
    }

    // Function for users to claim their earnings
    function ClaimEarnings(uint256 game_id) public {
        require(block.timestamp > pollEndTime, "Vote not yet finished.");

        uint256 earned;
        uint256 spent;
        bool claimed;
        (earned, spent, claimed) = GetEarnings();
        require(
            earned > 0 && spent > 0 && !claimed,
            "No earnings to claim or already claimed"
        );

        voters[msg.sender].claimed[game_id] = true;
        // voters[msg.sender].credits = voters[msg.sender].credits.add(earned);
        // depositFunds(msg.sender, earned);
        Bank(bankContract).depositFromYesNo{value: earned}(
            msg.sender,
            marketplace
        );
    }

    // Function to withdraw funds from the Bank contract
    function withdrawFunds(
        uint256 amount,
        address payable _withdrawer
    ) external payable {
        // Here withdrawer is the person whose amount is to be withdrawn from the bank
        Bank(payable(bankContract)).withdrawFromYesNo(
            _withdrawer,
            amount,
            marketplace
        );
    }

    // Function for users to cast their votes
    function CastVote(uint256 amount, VoteType vote_type) external payable {
        require(amount > 0, "Amount must be greater than zero");
        // require(amount <= voters[msg.sender].credits, "Insufficient credits");
        // Check bank or credit balance here
        require(checkBankBalance() >= amount, "Insufficient credits");
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

        // voters[msg.sender].credits = voters[msg.sender].credits.sub(amount);
        // withdrawFunds(amount, payable(msg.sender));
        Bank(payable(bankContract)).withdrawFromYesNo(
            payable(msg.sender),
            amount,
            marketplace
        );
        voters[msg.sender].votes[gameID].push(v);
        emit NewVoteCast();
    }

    // Function to get the winner of the current game
    function GetWinner() public view returns (string memory) {
        uint256 current_game_id = pollEndTime / block.timestamp;
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

    function setPollEndTime(uint256 _seconds) private onlyMarketPlace {
        pollEndTime = (block.timestamp).add(_seconds); // 60 seconds for voting
    }

    // Function to set the end time for voting
    function checkPollEndTime() public view returns (uint256) {
        return pollEndTime;
    }

    function getOwner() public view returns (address) {
        return owner_address;
    }

    function checkBankBalance() internal view returns (uint256) {
        return Bank(bankContract).balanceOf(msg.sender);
    }

    // Receive function to accept incoming ether
    receive() external payable {}
}

/******************************************************************************/
