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

contract YesNo {
    ////////////////////////////////////////////////////////////////////////////

    using SafeMath for uint256;

    ////////////////////////////////////////////////////////////////////////////

    uint constant BLOCK_DIV = 4096; // can initailize with the block count as time based

    /////////////////////////////////////////////////////////////////////////////
    enum VoteType {
        VOTE_YES,
        VOTE_NO
    }

    /*
     *  A `Vote` is the core of the is contract, this corresponds to some amount
     *  of ether (or X) being bet for the specified block number. The block
     *  number is of significance since each bet that a user makes falls within
     *  a `game` which spans `BLOCK_DIV` blocks.
     */
    struct Vote {
        uint256 game_id /* block.number / `BLOCK_DIV` */; // Only for the event info
        uint256 amount /* credits, 1 eth = 1000 credits */;
        VoteType vote_type /* yes or no? */;
    }

    /*
     *  A `Poll` represents one of the `BLOCK_DIV` block polls.
     */
    struct Poll {
        uint256 yes_total;
        uint256 no_total;
    }

    /*
     *  A `Voter` represents one player's balance, votes and amount in play.
     */
    struct Voter {
        mapping(uint256 => Vote[]) votes;
        mapping(uint256 => bool) claimed;
        uint256 credits;
    }

    ////////////////////////////////////////////////////////////////////////////

    mapping(address => Voter) private voters;
    mapping(uint256 => Poll) private poll_totals;

    ////////////////////////////////////////////////////////////////////////////

    /*
     *  The poll broadcast will automatically encode the block number that the
     *  log was created with. This allows any client to update the round totals
     *  by querying the contract's public view methods.
     */
    event NewVoteCast();

    address public owner_address;

    constructor() {
        owner_address = msg.sender;
    }

    ////////////////////////////////////////////////////////////////////////////

    function BuyCredits() public payable returns (bool) {
        voters[msg.sender].credits = voters[msg.sender].credits.add(msg.value);
        return true;
    }

    function WithdrawCredits(uint amount) public {
        require(amount <= voters[msg.sender].credits, "Need more minerals");
        voters[msg.sender].credits = voters[msg.sender].credits.sub(amount);
        payable(msg.sender).transfer(amount);
    }

    function GetCreditBalance() public view returns (uint) {
        return voters[msg.sender].credits;
    }

    ////////////////////////////////////////////////////////////////////////////

    function GetCurrentGame() public view returns (uint) {
        return block.number / BLOCK_DIV;
    }

    function GetGameTotals(uint index) public view returns (uint, uint) {
        require(index <= (block.number / BLOCK_DIV));
        return (poll_totals[index].yes_total, poll_totals[index].no_total);
    }

    function GetEarnings(uint game_id) public view returns (uint, uint, bool) {
        uint current_game_id = block.number / BLOCK_DIV;
        require(game_id <= current_game_id);

        uint256 earned = 0; /* Round winnings */
        uint256 spent = 0; /* Spend counter  */
        bool claimed = voters[msg.sender].claimed[game_id]; /* Naughty check  */
        require(!claimed, "Naughty Claim");
        uint256 r = poll_totals[game_id].yes_total;
        uint256 b = poll_totals[game_id].no_total;

        for (uint i = 0; i < voters[msg.sender].votes[game_id].length; i++) {
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

    ////////////////////////////////////////////////////////////////////////////

    function ClaimEarnings(uint game_id) public {
        uint256 current_game_id = block.number / BLOCK_DIV;
        require(game_id != current_game_id, "Cannot claim for active round");
        require(
            voters[msg.sender].claimed[game_id] == false,
            "Double claim? naughty naughty"
        );

        uint256 earned;
        uint256 spent;
        bool claimed;
        (earned, spent, claimed) = GetEarnings(game_id);
        require(
            earned > 0 && spent > 0 && !claimed,
            "Can't make what you don't spend"
        );
        voters[msg.sender].claimed[game_id] = true;
        voters[msg.sender].credits = voters[msg.sender].credits.add(earned);
        return;
    }

    ////////////////////////////////////////////////////////////////////////////

    function CastVote(uint amount, VoteType vote_type) public {
        require(amount <= voters[msg.sender].credits, "Not enough credits");

        Vote memory v;
        v.game_id = block.number / BLOCK_DIV;
        v.amount = amount;
        v.vote_type = vote_type;
        if (vote_type == VoteType.VOTE_YES) {
            poll_totals[block.number / BLOCK_DIV].yes_total = poll_totals[
                block.number / BLOCK_DIV
            ].yes_total.add(amount);
        } else if (vote_type == VoteType.VOTE_NO) {
            poll_totals[block.number / BLOCK_DIV].no_total = poll_totals[
                block.number / BLOCK_DIV
            ].no_total.add(amount);
        }
        voters[msg.sender].credits = voters[msg.sender].credits.sub(amount);
        voters[msg.sender].votes[block.number / BLOCK_DIV].push(v);
        emit NewVoteCast();
    }

    ////////////////////////////////////////////////////////////////////////////
}

/******************************************************************************/
