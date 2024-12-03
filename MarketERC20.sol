// SPDX-License-Identifier: MIT

// The market functionality has been largely forked from uiswap.
// Adaptions to the code have been made, to remove functionality that is not needed,
// or to adapt to the remaining code of this project.
// For the original uniswap contracts plese see:
// https://github.com/uniswap
//

pragma solidity ^0.8.0;

import "./openzeppelin/ERC20.sol";
import "./openzeppelin/Math2.sol";


contract MarketERC20 is ERC20{
    
    string public override constant name = 'TWIN LP Token';
    string public override constant symbol = 'TWIN_LPT';
    uint8 public override constant decimals = 18;
    //mapping (address => uint256) private _balances;
    //uint256 internal _totalSupply;
    
    uint256 public numberOfHolders;
    address[] public holders;
    
    //bytes32 public DOMAIN_SEPARATOR;
    //bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    //mapping(address => uint256) public nonces;

    constructor() ERC20(name, symbol) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        //DOMAIN_SEPARATOR = keccak256(
        //    abi.encode(
        //        keccak256('EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'),
        //        keccak256(bytes(name)),
        //        keccak256(bytes('1')),
        //        chainId,
        //        address(this)
        //    )
        //);
    }






    // allows transfer to zero instead of the normal ERC20 _mint function
    function _mint(address account, uint256 amount) internal override {
        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }
    

    
}