pragma solidity ^0.4.18;

contract Referendum {
    struct Option {
        uint voteCount;
        string name;
    }
    struct Poll {
        bool exists;
        address author;
        uint currentVoteCount;
        uint targetVoteCount;
        uint optionsCount;
        Option[] options;
        // User ID => Is whitelisted?
        mapping (address => bool) whitelist;
        // User ID => Has voted?
        mapping (address => bool) voted;
    }

    // Params: Poll ID, Option ID
    event NewVote(uint, uint);

    // Params: Poll ID, Winner Option ID (-1 if no winner)
    event PollComplete(uint, int);

    uint pollCount;

    // Poll ID => Poll
    mapping (uint => Poll) polls;

    constructor() public {}

    /// Create a new poll with given options and target votes count.
    function newPoll(bytes32[] options, uint targetVoteCount) public returns (uint pollID) {
        if (targetVoteCount == 0) return;

        pollID = pollCount++;
        Poll storage p = polls[pollID];
        p.exists = true;
        p.author = msg.sender;
        p.targetVoteCount = targetVoteCount;
        p.optionsCount = options.length;
        p.options.length = options.length;
        for (uint i = 0; i < options.length; i++) {
            p.options[i].name = bytes32ToString(options[i]);
        }
    }

    function giveRightToVote(uint pollID, address to) public {
        if (pollID >= pollCount) return;

        Poll storage p = polls[pollID];
        if (!p.exists) return;
        if (msg.sender != p.author || p.voted[to]) return;

        p.whitelist[to] = true;
    }

    function options(uint pollID) public view returns (bytes32[]) {
        // Ignore out of bounds params
        if (pollID >= pollCount) return;

        // Get poll by ID
        Poll storage p = polls[pollID];

        bytes32[] memory opts = new bytes32[](p.optionsCount);

        for (uint i = 0; i < p.optionsCount; i++) {
            opts[i] = stringToBytes32(p.options[i].name);
        }

        return opts;
    }

    function vote(uint pollID, uint optionID) public {
        // Ignore out of bounds params
        if (pollID >= pollCount || optionID >= p.optionsCount) return;

        // Get poll by ID
        Poll storage p = polls[pollID];
        // Ignore already completed polls
        if (p.currentVoteCount >= p.targetVoteCount) return;
        // Ignore non-existant polls
        if (!p.exists) return;
        // Ignore non-whitelisted users
        if (!p.whitelist[msg.sender]) return;
        // Ignore already voted senders
        if (p.voted[msg.sender]) return;

        p.options[optionID].voteCount = p.options[optionID].voteCount + 1;
        p.currentVoteCount = p.currentVoteCount + 1;
        p.voted[msg.sender] = true;

        // Notify of a new vote
        emit NewVote(pollID, optionID);

        if (p.currentVoteCount >= p.targetVoteCount) {
            // Notify of a completed poll
            emit PollComplete(pollID, winner(pollID));
        }
    }

    // Returns a winner option ID for a given poll ID
    function winner(uint pollID) public view returns (int) {
        // Ignore out of bounds params
        if (pollID >= pollCount) return;

        // Get poll by ID
        Poll storage p = polls[pollID];

        // Ignore out of bounds params
        if (p.optionsCount == 0) return;

        uint max = 0;
        int optionID = -1;
        for (uint i = 0; i < p.optionsCount; i++) {
            if (p.options[i].voteCount > max) {
                max = p.options[i].voteCount;
                optionID = int(i);
            }
        }

        return optionID;
    }

    function bytes32ToString(bytes32 x) private pure returns (string) {
        bytes memory bytesString = new bytes(32);
        uint charCount = 0;
        for (uint j = 0; j < 32; j++) {
            byte char = byte(bytes32(uint(x) * 2 ** (8 * j)));
            if (char != 0) {
                bytesString[charCount] = char;
                charCount++;
            }
        }
        bytes memory bytesStringTrimmed = new bytes(charCount);
        for (j = 0; j < charCount; j++) {
            bytesStringTrimmed[j] = bytesString[j];
        }
        return string(bytesStringTrimmed);
    }

    function stringToBytes32(string memory source) private pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(source);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(source, 32))
        }
    }
}