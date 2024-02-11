// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "forge-std/Test.sol";
import {BreakingTheHabit} from "../src/BreakingTheHabit.sol";

contract BreakingTheHabitTest is Test {

    BreakingTheHabit bth;

    function setUp() public {
        bth = new BreakingTheHabit("Breaking The Habit", "BTH");
    }

    function test_mint(string memory habit, address recipient) public {
        vm.assume(recipient != address(0));

        bth.mint(habit, recipient);

        BreakingTheHabit.BadHabit memory badHabit = bth.getHabit(1);
        assertEq(badHabit.habit, habit);
        assertEq(badHabit.currentStreak, 1);
        assertEq(badHabit.longestStreak, 1);
        assertEq(bth.ownerOf(1), recipient);
    }

    function test_breakTheHabit(address hacker, uint256 interactionDelay) public {
        address bread = makeAddr("bcBread");

        vm.assume(hacker != bread && hacker != address(0));

        if (interactionDelay < 1 hours) {
            interactionDelay = 1 hours;
        } else if (interactionDelay > 21 hours) {
            interactionDelay = 21 hours;
        }

        // assert hacker can't interact
        vm.expectRevert("Not authorized");
        vm.prank(hacker);
        bth.breakTheHabit(1);

        // create habit
        bth.mint("Smoking Cigarettes", bread);

        // try interacting within 16 hours
        vm.expectRevert("Cannot interact at this time, please wait longer");
        vm.prank(bread);
        bth.breakTheHabit(1);

        vm.warp(block.timestamp + 15 hours);

        vm.expectRevert("Cannot interact at this time, please wait longer");
        vm.prank(bread);
        bth.breakTheHabit(1);

        // interact within 16 - 36 hours
        vm.warp(block.timestamp + interactionDelay);
        vm.prank(bread);
        bth.breakTheHabit(1);

        BreakingTheHabit.BadHabit memory badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 2);
        assertEq(badHabit.longestStreak, 2);

        // try interacting again and should fail
        vm.expectRevert("Cannot interact at this time, please wait longer");
        vm.prank(bread);
        bth.breakTheHabit(1);

        vm.warp(block.timestamp + 15 hours);

        vm.expectRevert("Cannot interact at this time, please wait longer");
        vm.prank(bread);
        bth.breakTheHabit(1);

        // wait too long and reset longest streak
        vm.warp(block.timestamp + 21 hours + 1);
        vm.prank(bread);
        bth.breakTheHabit(1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 1);
        assertEq(badHabit.longestStreak, 2);

        // interact via operator
        vm.prank(bread);
        bth.approve(hacker, 1);

        vm.warp(block.timestamp + 16 hours);

        vm.prank(hacker);
        bth.breakTheHabit(1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 2);
        assertEq(badHabit.longestStreak, 2);

        // get longer streak
        vm.warp(block.timestamp + 16 hours);

        vm.prank(hacker);
        bth.breakTheHabit(1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 3);
        assertEq(badHabit.longestStreak, 3);

        // break streak and ensure that can get to streak of 2 while retaining longest streak of 3
        vm.warp(block.timestamp + 36 hours + 1);

        vm.prank(hacker);
        bth.breakTheHabit(1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 1);
        assertEq(badHabit.longestStreak, 3);

        vm.warp(block.timestamp + 16 hours);

        vm.prank(hacker);
        bth.breakTheHabit(1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 2);
        assertEq(badHabit.longestStreak, 3);

        // test reset on transfer
        vm.prank(bread);
        bth.transferFrom(bread, hacker, 1);

        badHabit = bth.getHabit(1);
        assertEq(badHabit.currentStreak, 1);
        assertEq(badHabit.longestStreak, 1);
    }

    function test_tokenURI() public {
        address bread = makeAddr("bcBread");
        bth.mint("Smoking cigarettes", bread);
        vm.warp(block.timestamp + 16 hours);
        vm.prank(bread);
        bth.breakTheHabit(1);
        string memory uri = bth.tokenURI(1);

        console.log(uri);
    }
}