/// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title POWRAI Token
/// @author Tokeny
/// @notice This contract implements an ERC20 token with additional features such as minting,
/// burning, pausing, capping, and blacklist management.
/// @dev The contract is based on OpenZeppelin libraries for security and standardization.
contract POWRAI is ERC20, ERC20Pausable, Ownable, ERC20Capped, ERC20Burnable  {
    /// @notice Mapping of addresses to their blacklist status.
    mapping(address => bool) private _blacklist;

    /// @notice Mapping of addresses to their blacklist manager status.
    mapping(address => bool) public blacklistManagers;

    /// @notice Emitted when an address is blacklisted.
    /// @param account The address that was blacklisted.
    event Blacklisted(address indexed account);

    /// @notice Emitted when an address is removed from the blacklist.
    /// @param account The address that was removed from the blacklist.
    event RemovedFromBlacklist(address indexed account);

    /// @notice Emitted when a new blacklist manager is added.
    /// @param account The address that was added as a blacklist manager.
    event BlacklistManagerAdded(address indexed account);

    /// @notice Emitted when a blacklist manager is removed.
    /// @param account The address that was removed as a blacklist manager.
    event BlacklistManagerRemoved(address indexed account);

    /// @notice Emitted when new tokens are minted.
    /// @param receiver The address receiving the minted tokens.
    /// @param amount The amount of tokens minted.
    event Minted(address indexed receiver, uint256 amount);

    /// @notice Thrown when a zero address is provided where it is not allowed.
    error NoZeroAddress();

    /// @notice Thrown when a caller is not a blacklist manager.
    /// @param caller The address of the caller attempting the operation.
    error NotBlacklistManager(address caller);

    /// @notice Thrown when a blacklisted address is involved in a restricted operation.
    /// @param blacklisted The blacklisted address.
    error BlacklistedAddress(address blacklisted);

    /// @notice Thrown when an address is already a blacklist manager.
    /// @param blManager The address already added as a blacklist manager.
    error AlreadyBlacklistManager(address blManager);

    /// @notice Thrown when attempting to remove an address not on the blacklist.
    /// @param wallet The address that is not on the blacklist.
    error AddressNotBlacklisted(address wallet);

    /// @notice Restricts access to functions to blacklist managers.
    modifier onlyBlacklistManager() {
        require(blacklistManagers[msg.sender], NotBlacklistManager(msg.sender));
        _;
    }

    /// @notice Deploys the POWRAI token with specified parameters.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    /// @param initialSupply The initial supply of tokens to mint to the owner.
    /// @param ownerAddress The address that will own the token contract.
    /// @param maxSupply The maximum supply of tokens that can ever exist.
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        address ownerAddress,
        uint256 maxSupply
    ) ERC20(name, symbol) Ownable(ownerAddress) ERC20Capped(maxSupply) {
        _mint(ownerAddress, initialSupply);
        blacklistManagers[ownerAddress] = true;
        _pause();
        emit BlacklistManagerAdded(ownerAddress);
    }

    /// @notice Adds a new blacklist manager.
    /// @dev Only callable by the owner.
    /// @param account The address to add as a blacklist manager.
    function addBlacklistManager(address account) external onlyOwner {
        require(account != address(0), NoZeroAddress());
        require(!blacklistManagers[account], AlreadyBlacklistManager(account));
        blacklistManagers[account] = true;
        emit BlacklistManagerAdded(account);
    }

    /// @notice Removes an existing blacklist manager.
    /// @dev Only callable by the owner.
    /// @param account The address to remove as a blacklist manager.
    function removeBlacklistManager(address account) external onlyOwner {
        require(account != address(0), NoZeroAddress());
        require(blacklistManagers[account], NotBlacklistManager(account));
        blacklistManagers[account] = false;
        emit BlacklistManagerRemoved(account);
    }

    /// @notice Adds an address to the blacklist.
    /// @dev Only callable by a blacklist manager.
    /// @param account The address to add to the blacklist.
    function addToBlacklist(address account) external onlyBlacklistManager {
        require(account != address(0), NoZeroAddress());
        require(!_blacklist[account], BlacklistedAddress(account));
        _blacklist[account] = true;
        emit Blacklisted(account);
    }

    /// @notice Removes an address from the blacklist.
    /// @dev Only callable by a blacklist manager.
    /// @param account The address to remove from the blacklist.
    function removeFromBlacklist(address account) external onlyBlacklistManager {
        require(account != address(0), NoZeroAddress());
        require(_blacklist[account], AddressNotBlacklisted(account));
        _blacklist[account] = false;
        emit RemovedFromBlacklist(account);
    }

    /// @notice Pauses all token transfers.
    /// @dev Only callable by the owner. Transfers will be blocked until unpaused.
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpauses all token transfers.
    /// @dev Only callable by the owner. Transfers will resume after unpausing.
    function unpause() external onlyOwner {
        _unpause();
    }

    /// @notice Mints new tokens to a specified address.
    /// @dev Only callable by the owner. The total supply cannot exceed the cap.
    /// @param _receiver The address receiving the minted tokens.
    /// @param _amount The amount of tokens to mint.
    function mint(address _receiver, uint256 _amount) external onlyOwner {
        _mint(_receiver, _amount);
        emit Minted(_receiver, _amount);
    }

    /// @notice Checks if an address is blacklisted.
    /// @param account The address to check.
    /// @return True if the address is blacklisted, false otherwise.
    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    /// @notice Internal function to handle updates to token balances.
    /// @dev Combines logic for ERC20, ERC20Capped, and ERC20Pausable.
    /// @dev blocks transfers from or to a blacklisted address
    /// @param from The address tokens are transferred from.
    /// @param to The address tokens are transferred to.
    /// @param amount The amount of tokens transferred.
    function _update(address from, address to, uint256 amount)
    internal
    virtual
    override(ERC20, ERC20Pausable, ERC20Capped)
    {
        require(!isBlacklisted(from), BlacklistedAddress(from));
        require(!isBlacklisted(to), BlacklistedAddress(to));
        super._update(from, to, amount);
    }
}
