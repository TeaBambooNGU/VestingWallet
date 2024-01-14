// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.20;
/**
 * 首先部署逻辑合约Logic。
 * 创建代理合约Proxy，状态变量implementation记录Logic合约地址。
 * Proxy合约利用回调函数fallback，将所有调用委托给Logic合约
 * 最后部署调用示例Caller合约，调用Proxy合约。
 * 注意：Logic合约和Proxy合约的状态变量存储结构相同，不然delegatecall会产生意想不到的行为，有安全隐患。
 */
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC20.sol";

contract ProxyContract {
    // 逻辑合约地址。implementation合约同一个位置的状态变量类型必须和Proxy合约的相同，不然会报错。
    address public implementation;

    constructor(address implementation_) {
        implementation = implementation_;
    }

    fallback() external payable {
        address _implementation = implementation;
        assembly {
            // 将msg.data拷贝到内存里
            // calldatacopy操作码的参数：内存起始位置 calldata起始位置 calldata长度
            calldatacopy(0,0,calldatasize())
            // 利用delegatecall调用implementation合约
            // delegatecall操作码的参数：gas, 目标合约地址，input mem起始位置， input mem长度 output area mem起始位置，output area mem长度
            // output area起始位置和长度位置 所以设为0
            // delegatecall成功返回1，失败返回0
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)

            // 将return data拷贝到内存
            // returndata 操作码的参数：内存起始位置，returndata起始位置， returndata长度
            returndatacopy(0,0,returndatasize())

            switch result
            // 如果delegate call失败, revert
            case 0 {
                revert(0, returndatasize())
            }
            // 如果delegate call成功，返回mem起始位置为0，长度为returndatasize()的数据（格式为bytes）
            default {
                return(0, returndatasize())
            }


        }
    }


}