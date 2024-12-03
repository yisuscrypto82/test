// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
//import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./openzeppelin/ERC20.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";


contract GovernanceToken is Ownable(msg.sender), ERC20,ILayerZeroReceiver {
  ILayerZeroEndpoint public endpoint;
  mapping(uint16 => bytes) public remotes;

  
 
  constructor(string memory name_, string memory symbol_, address _layerZeroEndpoint) ERC20(name_, symbol_) {
    endpoint = ILayerZeroEndpoint(_layerZeroEndpoint);       
  }
  
    // send tokens to another chain.
    // this function sends the tokens from your address to the same address on the destination.
    function sendTokens(
        uint16 _chainId,                            // send tokens to this chainId
        bytes calldata _dstOmniChainTokenAddr,     // destination address of OmniChainToken
        uint _qty                                   // how many tokens to send
    )
        public
        payable
    {
        // burn the tokens locally.
        // tokens will be minted on the destination.
        require(
            allowance(msg.sender, address(this)) >= _qty,
            "You need to approve the contract to send your tokens!"
        );

        // and burn the local tokens *poof*
        _burn(msg.sender, _qty);

        // abi.encode() the payload with the values to send
        bytes memory payload = abi.encode(msg.sender, _qty);

        // send LayerZero message
        endpoint.send{value:msg.value}(
            _chainId,                       // destination chainId
            _dstOmniChainTokenAddr,        // destination address of OmniChainToken
            payload,                        // abi.encode()'ed bytes
            payable(msg.sender),            // refund address (LayerZero will refund any superflous gas back to caller of send()
            address(0x0),                   // 'zroPaymentAddress' unused for this mock/example
            bytes("")                       // 'txParameters' unused for this mock/example
        );
    }

    // _chainId - the chainId for the remote contract
    // _remoteAddress - the contract address on the remote chainId
    // the owner must set remote contract addresses.
    // in lzReceive(), a require() ensures only messages
    // from known contracts can be received.
    function setRemote(uint16 _chainId, bytes calldata _remoteAddress) external onlyOwner {
        require(remotes[_chainId].length == 0, "The remote address has already been set for the chainId!");
        remotes[_chainId] = _remoteAddress;
    }

    // receive the bytes payload from the source chain via LayerZero
    // _fromAddress is the source OmniChainToken address
    function lzReceive(uint16 _srcChainId, bytes memory _srcAddress, uint64, bytes memory _payload) override external{
        require(msg.sender == address(endpoint)); // boilerplate! lzReceive must be called by the endpoint for security
        // owner must have setRemote() to allow its remote contracts to send to this contract
        require(
            _srcAddress.length == remotes[_srcChainId].length && keccak256(_srcAddress) == keccak256(remotes[_srcChainId]),
            "Invalid remote sender address. owner should call setRemote() to enable remote contract"
        );

        // decode
        (address toAddr, uint qty) = abi.decode(_payload, (address, uint));

        // mint the tokens back into existence, to the toAddr from the message payload
        _mint(toAddr, qty);
    }


  



  /**
  * @notice A method that mints new governance tokens. Can only be called by the owner.
  * @param _address Address that receives the governance tokens.
  *        _amount Amount to governance tokens to be minted in WEI.
  */
  function mint(
    address _address, 
    uint256 _amount
    ) 
    external 
    onlyOwner 
    {
  	_mint(_address, _amount);
  }

  /**
  * @notice A method that burns governance tokens. Can only be called by the owner.
  * @param _address Address that receives the governance tokens.
  *        _amount Amount to governance tokens to be minted in WEI.
  */
  function burn(
    address _address,
    uint256 _amount
    ) 
    external 
    onlyOwner {
    _burn(_address, _amount);
  }

  
}