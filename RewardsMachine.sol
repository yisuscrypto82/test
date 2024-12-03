// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./GovernanceToken.sol";
import "./VotingEscrow.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardsMachine is Initializable{
    address public controlAccount;
    uint256 public nextRewardsPayment;
    uint256 public currentRewardsSnapshot;
    uint256 public maxGoveranceTokenSupply;
    uint256 public rewardsRound;
    mapping(uint256 => uint256) public rewardTokenNumbersPerRound;
    mapping (address => uint256) public lastRewardsRound;
    mapping(uint256 => uint256) public snapshotByRound;

    GovernanceToken public governanceToken;
    VotingEscrow public votingEscrow;
    
    address public voteMachineAddress;
    uint256 public rewardTokenNumber;
    uint256 public undistributedRewards;
    address public rewardsManagerAddress;

    bool public isPaused;
    address pauseAccount;
    
    // Modifier to check that the caller is the owner of
    // the contract.
    modifier notPaused() {
        require(isPaused == false, "CONTRACT_PAUSED");
        _;
    }

    function pauseContract(
        )
        public
        {
        require(msg.sender == pauseAccount,"NOT_PAUSEACCOUNT");
        isPaused = true;
    }

    function unpauseContract(
        )
        public
        {
        require(msg.sender == pauseAccount,"NOT_PAUSEACCOUNT");
        isPaused = false;
    }
    
    function initialize(
        GovernanceToken _governanceToken,
        VotingEscrow _votingEscrow,
        address _pauseAccount,
        address _rewardsManagerAddress 
        ) 
        public initializer 
        {
        governanceToken = _governanceToken;
        votingEscrow = _votingEscrow;
        pauseAccount = _pauseAccount;
        rewardsManagerAddress = _rewardsManagerAddress;
        nextRewardsPayment = 0;
        maxGoveranceTokenSupply = 100000000 * (10 ** 18);
        rewardsRound = 1;
    }




    // Safe Governance Token transfer function, just in case if rounding error causes pool to not have enough tokens.
    function distributeRewards(address _to, uint256 _amount) internal notPaused {
        uint256 balance = governanceToken.balanceOf(address(this));
        uint256 amountToTransfer = (_amount > balance) ? balance : _amount;
        
        // Update undistributed rewards to reflect the transfer
        if (amountToTransfer <= undistributedRewards) {
            undistributedRewards -= amountToTransfer;
        } else {
            undistributedRewards = 0; // Ensure it doesn’t go negative
        }

        governanceToken.transfer(_to, amountToTransfer);
    }


   

    /**
    * @notice A method that lets an external contract fetch the current supply of the governance token.
    */
    function getCurrentSupply() 
        external
        view 
        returns (uint256) 
        {
        uint256 currentGovernanceTokenSupply = governanceToken.balanceOf(address(this));
        return (currentGovernanceTokenSupply);
    }

    
    

    /**
    * @notice A method that creates the weekly reward tokens. Can only be called once per week.
    */
    function createRewards() 
        external
        notPaused
        returns (uint256) 
    {
        require(nextRewardsPayment < block.timestamp, "TIME_NOT_UP");
        
        // Store the current block number in snapshotByRound for this round
        snapshotByRound[rewardsRound] = block.number;

        uint256 availableRewards = governanceToken.balanceOf(address(this)) - undistributedRewards;
        uint256 weeklyRewards = availableRewards / 10;

        rewardTokenNumber = weeklyRewards * votingEscrow.totalSupplyAt(snapshotByRound[rewardsRound]) / 
                            (maxGoveranceTokenSupply - governanceToken.balanceOf(address(this)));

        undistributedRewards += weeklyRewards;
        governanceToken.transfer(rewardsManagerAddress, weeklyRewards);

        nextRewardsPayment = block.timestamp + 7 days;
        rewardsRound += 1;

        return weeklyRewards;
    }





    /**
    * @notice A method that claims the rewards for the calling address.
    */
    function claimRewards()
        external
        notPaused
        returns (uint256)
    {
        uint256 lastClaimedRound = lastRewardsRound[msg.sender];
        require(lastClaimedRound < rewardsRound - 1, "ALL_REWARDS_CLAIMED");

        uint256 totalVotingRewards = 0;

        // Loop through each missed round to accumulate rewards
        for (uint256 round = lastClaimedRound + 1; round < rewardsRound; round++) {
            uint256 veAmount = votingEscrow.balanceOfAt(msg.sender, snapshotByRound[round]);
            uint256 totalVeSupply = votingEscrow.totalSupplyAt(snapshotByRound[round]);

            uint256 votingRewards = (totalVeSupply > 0) ? 
                rewardTokenNumbersPerRound[round] * veAmount / totalVeSupply : 0;
            totalVotingRewards += votingRewards;
        }

        lastRewardsRound[msg.sender] = rewardsRound - 1;
        distributeRewards(msg.sender, totalVotingRewards);

        return totalVotingRewards;
    }





    /**
    * @notice A method that gets the pending rewards for a specific address.
    * @param  _address Address for the pending rewards are checked
    */
    
    function getRewards(address _address)
        external
        view
        returns (uint256)
    {
        uint256 lastClaimedRound = lastRewardsRound[_address];
        if (lastClaimedRound >= rewardsRound - 1) return 0;

        uint256 totalPendingRewards = 0;

        for (uint256 round = lastClaimedRound + 1; round < rewardsRound; round++) {
            uint256 veAmount = votingEscrow.balanceOfAt(_address, snapshotByRound[round]);
            uint256 totalVeSupply = votingEscrow.totalSupplyAt(snapshotByRound[round]);

            uint256 votingRewards = (totalVeSupply > 0) ? 
                rewardTokenNumbersPerRound[round] * veAmount / totalVeSupply : 0;
            totalPendingRewards += votingRewards;
        }

        return totalPendingRewards;
    }


}
