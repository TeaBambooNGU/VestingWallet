// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract TokenLocker is Ownable {

    event TokenLockStart(address indexed beneficiary, address indexed token, uint256 startTime, uint256 lockTime);
    event Release(address indexed beneficiary. address indexed token, uint256 releaseTime, uint256 amount);
    // 被锁仓的ERC20代币合约
    IERC20 public immutable token;
    // 受益人地址
    address public immutable beneficiary;
    // 锁仓时间(秒)
    uint256 public immutable lockTime;
    // 锁仓起始时间戳（秒）
    uint256 public immutable startTime;

    constructor(IERC20 token_, address beneficiary_, uint256 lockTime_)  {
        require(lockTime_ > 0, "TokenLock: lock time should greater than 0");
        token = token_;
        beneficiary = beneficiary_;
        lockTime = lockTime_;
        startTime = block.timestamp;
    }

    function release() public {
        require(block.timestamp >= startTime+lockTime,"TokenLock: current time is before release time");

        uint256 amount = token.balanceOf(address(this));
        require(amount > 0,"TokenLock: no tokens to release");
        token.transfer(beneficiary,amount);
        emit Release(beneficiary,address(token),block.timestamp,amount);
        
    }


}