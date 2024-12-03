// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract TestProxy is Initializable{
    string public greet;
    function initialize(
		string memory _greet
		) 
		public initializer 
		{
        greet = _greet;
    }
}