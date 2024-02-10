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

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {}

    /*//////////////////////////////////////////////////////////////////////////
                                Mint & Interact
    //////////////////////////////////////////////////////////////////////////*/

    /// @notice Mint function, callable by anyone, minted to msg.sender's address.
    /// @dev Saves the habit passed in and starts the streak at 1 (you should start with something)
    function mint(string calldata habit) external {
        uint256 tokenId = ++_counter;
        BadHabit memory badHabit = BadHabit({
            habit: habit,
            lastInteractedTimestamp: block.timestamp,
            currentStreak: 1,
            longestStreak: 1
        });
        _badHabits[tokenId] = badHabit;
        _mint(msg.sender, tokenId);
    }

    /// @notice Function to interact and keep the streak alive
    /// @dev Since there is no concept of what day it is, we need to just use monotoically incrementing time periods. Basically, if called within 16-36 hours of the previous timestamp, will continue the streak. If prior, reverts. If after, resets the current streak.
    function breakTheHabit(uint256 tokenId) external {
        // check if token owner
        _requireOwned(tokenId);

        // get habit
        BadHabit memory badHabit = _badHabits[tokenId];

        // logic for streak
        uint256 timeInterval = block.timestamp - badHabit.lastInteractedTimestamp;
        if (timeInterval < 16 hours) {
            revert("Cannot interact at this time, please wait longer");
        } else if (timeInterval >= 16 hours && timeInterval <= 36 hours) {
            badHabit.currentStreak++;
            badHabit.longestStreak = badHabit.currentStreak;
        } else {
            badHabit.currentStreak = 1;
        }
        badHabit.lastInteractedTimestamp = block.timestamp;

        // save habit 
        _badHabits[tokenId] = badHabit;
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
        string memory base64Svg = _buildSvg(badHabit);

        // generate html
        bytes32 hash = keccak256(abi.encodePacked(badHabit.habit, owner));
        string memory base64Html = _buildHtml(badHabit, tokenId, hash);

        // generate json
        bytes memory json = abi.encodePacked(
            '{',
            '"name": "Breaking The Habit #', tokenId.toString(), '",',
            '"description": "', owner.toHexString(), ' is trying to break the habit of ', badHabit.habit, '. This NFT is meant to help them through the process in a fun way!",',
            '"attributes": [',
            '{"trait_type": "background", "value": #', uint256(hash).toHexString(3), '"},',
            '{"trait_type": "current streak", "value": "', badHabit.currentStreak.toString(), '"},',
            '{"trait_type": "longest streak", "value": "', badHabit.longestStreak.toString(), '"}',
            '],',
            '"image": "', base64Svg, '",',
            '"animation_url": "', base64Html, '"'
            '}'
        );

        return string(abi.encodePacked(
            'data:application/json;base64,',
            Base64.encode(json)
        ));
    }

    function _buildSvg(BadHabit memory badHabit) private pure returns (string memory) {
        bytes memory svg = abi.encodePacked(
            '<svg viewBox="0 0 240 240" xmlns="http://www.w3.org/2000/svg">',
            '<text x="50%" y="50%" text-anchor="middle">', badHabit.habit,'</text>',
            '</svg>'
        );
        return string(
            abi.encodePacked(
                'data:image/svg+xml;base64,',
                Base64.encode(svg)
            )
        );
    }

    function _buildHtml(BadHabit memory badHabit, uint256 tokenId, bytes32 hash) private pure returns (string memory) {
        string memory color = badHabit.currentStreak < badHabit.longestStreak ? "red" : "green";
        string memory text = badHabit.currentStreak < badHabit.longestStreak ? "Get back at it!" : "Keep up the good work!";
        bytes memory html =abi.encodePacked(
            '<!DOCTYPE html>',
            '<html lang="en">',
            '<head>',
            '<meta charset="UTF-8">',
            '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
            '<title>Breaking The Habit #', tokenId.toString(), '</title>',
            '<style>',
            '.red {color: red;}',
            '.green {color: green;}',
            'body {background-color: #', uint256(hash).toHexString(3), ';}',
            '</style>',
            '</head>',
            '<body>',
            '<h3>Habit: ', badHabit.habit, '</h3>',
            '<p class="', color, '">Current Streak: ', badHabit.currentStreak.toString(), '</p>',
            '<p>Longest Streak: ', badHabit.longestStreak.toString(), '</p>',
            '<h4>', text, '</h4>',
            '</body>',
            '</html>' 
        );

        return string(
            abi.encodePacked(
                'data:text/html;base64,',
                Base64.encode(html)
            )
        );
    }
}