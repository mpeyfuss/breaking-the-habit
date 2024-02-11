// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import {ERC721} from "openzeppelin/token/ERC721/ERC721.sol";
import {Base64} from "openzeppelin/utils/Base64.sol";
import {Strings} from "openzeppelin/utils/Strings.sol";

/// @title Breaking The Habit
/// @notice NFT contrat to help keep you accountable while trying to break a bad habit
/// @author @mpeyfuss
contract BreakingTheHabit is ERC721 {

    /*//////////////////////////////////////////////////////////////////////////
                                Custom Types
    //////////////////////////////////////////////////////////////////////////*/

    using Strings for uint256;
    using Strings for address;

    struct BadHabit {
        string habit;
        uint256 lastInteractedTimestamp;
        uint256 currentStreak;
        uint256 longestStreak;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                State Variables
    //////////////////////////////////////////////////////////////////////////*/

    uint256 private _counter;
    mapping(uint256 => BadHabit) private _badHabits; // tokenId -> BadHabit

    /*//////////////////////////////////////////////////////////////////////////
                                Constructor
    //////////////////////////////////////////////////////////////////////////*/

    constructor() ERC721("Breaking The Habit", "BTH") {}

    /*//////////////////////////////////////////////////////////////////////////
                                Mint & Interact
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Mint function, callable by anyone, minted to msg.sender's address.
    /// @dev Saves the habit passed in and starts the streak at 1 (you should start with something)
    function mint(string calldata habit, address recipient) external {
        uint256 tokenId = ++_counter;
        BadHabit memory badHabit = BadHabit({
            habit: habit,
            lastInteractedTimestamp: block.timestamp,
            currentStreak: 1,
            longestStreak: 1
        });
        _badHabits[tokenId] = badHabit;
        _mint(recipient, tokenId);
    }

    /// @notice Function to interact and keep the streak alive
    /// @dev Since there is no concept of what day it is, we need to just use monotoically incrementing time periods. Basically, if called within 16-36 hours of the previous timestamp, will continue the streak. If prior, reverts. If after, resets the current streak.
    function breakTheHabit(uint256 tokenId) external {
        // check if token owner or an approved operator (allows for interesting services to be built, for example, in farcaster, maybe)
        address owner = _ownerOf(tokenId);
        require(_isAuthorized(owner, msg.sender, tokenId), "Not authorized");

        // get habit
        BadHabit memory badHabit = _badHabits[tokenId];

        // logic for streak
        uint256 timeInterval = block.timestamp - badHabit.lastInteractedTimestamp;
        if (timeInterval < 16 hours) {
            revert("Cannot interact at this time, please wait longer");
        } else if (timeInterval >= 16 hours && timeInterval <= 36 hours) {
            badHabit.currentStreak++;
            if (badHabit.currentStreak > badHabit.longestStreak) {
                badHabit.longestStreak = badHabit.currentStreak;
            }
        } else {
            badHabit.currentStreak = 1;
        }
        badHabit.lastInteractedTimestamp = block.timestamp;

        // save habit 
        _badHabits[tokenId] = badHabit;
    }

    /// @notice function to get a habit
    function getHabit(uint256 tokenId) external view returns (BadHabit memory) {
        return _badHabits[tokenId];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    Overrides
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice function to reset the streak on transfer
    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        BadHabit memory badHabit = _badHabits[tokenId];
        badHabit.currentStreak = 1;
        badHabit.longestStreak = 1;
        badHabit.lastInteractedTimestamp = block.timestamp;
        _badHabits[tokenId] = badHabit;

        return super._update(to, tokenId, auth);
    }

    /// @notice function to override token uri functionality and return back on-chain art
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = _requireOwned(tokenId);
        
        // get habit
        BadHabit memory badHabit = _badHabits[tokenId];

        // generate svg
        bytes32 hash = keccak256(abi.encodePacked(badHabit.habit, owner));
        uint256 colorNum = ((uint256(hash) >> 232) << 232) >> 232;
        string memory color = string(
            abi.encodePacked(
                abi.encodePacked(colorNum.toHexString(3))[2],
                abi.encodePacked(colorNum.toHexString(3))[3],
                abi.encodePacked(colorNum.toHexString(3))[4],
                abi.encodePacked(colorNum.toHexString(3))[5],
                abi.encodePacked(colorNum.toHexString(3))[6],
                abi.encodePacked(colorNum.toHexString(3))[7]
            )
        );
        string memory base64Svg = _buildSvg(badHabit, color);

        // generate json
        bytes memory json = abi.encodePacked(
            '{',
            '"name": "Breaking The Habit #', tokenId.toString(), '",',
            '"description": "', owner.toHexString(), ' is trying to break the habit of ', badHabit.habit, '. This NFT is meant to help them through the process in a fun way!",',
            '"attributes": [',
            '{"trait_type": "background", "value": "#', color, '"},',
            '{"trait_type": "current streak", "value": "', badHabit.currentStreak.toString(), '"},',
            '{"trait_type": "longest streak", "value": "', badHabit.longestStreak.toString(), '"}',
            '],',
            '"image": "', base64Svg, '"',
            '}'
        );

        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(json)
        ));
    }

    function _buildSvg(BadHabit memory badHabit, string memory color) private pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">',
            '<rect width="100%" height="100%" fill="#', color, '"/>',
            '<text x="5%" y="10%" font-size="small">Breaking The Habit</text>',
            '<text x="5%" y="20%">', badHabit.habit, '</text>',
            '<text x="5%" y="40%">Current Streak: ', badHabit.currentStreak.toString(), '</text>',
            '<text x="5%" y="50%" font-size="small">Longest Streak: ', badHabit.longestStreak.toString(), '</text>',
            '</svg>'
        );
        return string(
            abi.encodePacked(
                'data:image/svg+xml;base64,',
                Base64.encode(svg)
            )
        );
    }
}