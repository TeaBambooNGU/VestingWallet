// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/utils/Context.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
/**
 * 线性释放合约
 * 项目方规定线性释放的起始时间、归属期和受益人。
 * 项目方将锁仓的ERC20代币转账给VestingWallet合约。
 * 受益人可以调用release函数，从合约中取出释放的代币。
 * 例如：某私募持有365,000枚ICU代币，归属期为1年（365天），那么每天会释放1,000枚代币
 */
contract VestingWallet is Context, Ownable {
    // token释放事件 提币事件，当受益人提取释放代币时释放
    event ERC20Released(address indexed token, uint256 amount);

    event EtherReleased(uint256 amount);
    // 单个人的ETH释放数量
    uint256 private _released;
    // 代币地址->释放数量 记录受益人已领取的代币数量
    mapping (address token => uint256) _erc20Released;
    // 线性释放的起始时间
    uint256 private immutable _start;
    // 归属期，单位为秒
    uint256 private immutable _duration;

    /**
     * 构造函数
     * @param beneficiary 线性合约代币受益人
     * @param startTimestamp 起始时间戳
     * @param durationSeconds 归属期 单位秒
     */
    constructor(
        address beneficiary,
        uint64 startTimestamp, 
        uint256 durationSeconds) payable Ownable(beneficiary) {
        _start = startTimestamp;
        _duration = durationSeconds;
    }
    // 构造合约的时候 接收ETH 触发 receive
    receive() external payable {}

    function start() public view returns (uint256) {
        return _start;
    }

    function duration() public view returns (uint256) {
        return _duration;
    }

    function end() public view returns (uint256) {
        return start() + duration();
    }
    // ETH已经释放的释放数量
    function released() public view virtual returns (uint256) {
        return _released;
    }
    // 受益人已经获取到的代币数量
    function released(address token) public view returns (uint256) {
        return _erc20Released[token];
    }
    // 当前可释放的ETH数量
    function releasable() public view returns (uint256) {
        return _vestingSchedule(address(this).balance + released(),uint64(block.timestamp)) - released();
    }
    // 当前可释放的token数量
    function releasable(address token) public view returns (uint256) {
        // 合约里总共收到了多少代币（当前余额 + 已经提取）
        uint256 totalAllocation = IERC20(token).balanceOf(address(this))+released(token);
        return _vestingSchedule(totalAllocation,uint64(block.timestamp)) - released(token);
    }
    // 受益人提取已释放的ETH
    function release() public {
        uint256 amount = releasable();
        _released += amount;
        emit EtherReleased(amount);
        Address.sendValue(payable(owner()), amount);
    }

    function release(address token) public{
        uint256 amount = released(token);
        _erc20Released[token] += amount;
        emit ERC20Released(token,amount);
        SafeERC20.safeTransfer(IERC20(token),owner(),amount);
    }

    // 得到当前时间戳下应该已经分配的货币数量
    function vestedAmount(uint256 totalAllocation,uint64 timestamp) public view returns (uint256) {
        return _vestingSchedule(totalAllocation,timestamp);
    }

    /**
     * 分配函数
     * @param totalAllocation 总释放量
     * @param timestamp 当前时间戳
     */
    function _vestingSchedule(uint256 totalAllocation, uint64 timestamp) internal view returns (uint256) {
        if(timestamp < start()){
            return 0;
        } else if (timestamp >= end()){
            return totalAllocation;
        } else{
            return (totalAllocation * (timestamp - start())) / duration();
        }
    }


}