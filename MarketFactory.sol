// SPDX-License-Identifier: MIT

// The market functionality has been largely forked from uiswap.
// Adaptions to the code have been made, to remove functionality that is not needed,
// or to adapt to the remaining code of this project.
// For the original uniswap contracts plese see:
// https://github.com/uniswap
//

pragma solidity ^0.8.0;

import './interfaces/IMarketFactory.sol';
import './MarketPair.sol';
//import "@openzeppelin/contracts/access/Ownable.sol";

contract MarketFactory is IMarketFactory{
    address public controlAccount;
    address public override feeTo;
    address public override feeToSetter;

    mapping(address => mapping(address => address)) public override getPair;
    address[] public override allPairs;

    
    constructor(address _feeToSetter, address _feeTo) {
        feeToSetter = _feeToSetter;
        feeTo = _feeTo;
    }
  
    /**
    * @notice A method that returns the number of market pairs.
    */
    function allPairsLength() 
        external 
        view 
        override 
        returns (uint256) 
        {
        return allPairs.length;
    }

    
    

    /**
    * @notice A method that creates a new market pair for to tokens.
    * @param tokenA The first token in the pair
    *        tokenB The second token in the pair
    */
    function createPair(
        address tokenA, 
        address tokenB
        ) 
        external 
        override 
        returns (address pairAddress) 
        {
        require(tokenA != tokenB, 'IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'PAIR_EXISTS'); // single check is sufficient
        
        bytes memory bytecode = type(MarketPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pairAddress := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        //pairAddress = address(new MarketPair());
        MarketPair(pairAddress).initialize(token0, token1);
        getPair[token0][token1] = pairAddress;
        getPair[token1][token0] = pairAddress; // populate mapping in the reverse direction
        allPairs.push(pairAddress);
        emit PairCreated(token0, token1, pairAddress, allPairs.length);
        return pairAddress;
    }


    /**
    * @notice A method that sets the receiver of a trading fee.
    * @param _feeTo The address that will receive the trading fee
    */
    function setFeeTo(
        address _feeTo
        ) 
        external 
        override
        {
        require(msg.sender == feeToSetter, 'FORBIDDEN');
        feeTo = _feeTo;
    }

    /**
    * @notice A method that sets the address that that can set the receiver of the fees..
    * @param _feeToSetter Address that will be the new address that is allowed to set the fee.
    */
    function setFeeToSetter(
        address _feeToSetter
        )
        external 
        override 
        {
        require(msg.sender == feeToSetter, 'FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}



