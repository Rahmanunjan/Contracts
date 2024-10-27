// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

interface IOracle {
    function getPrice() external view returns (uint256);
}

contract RentStaking is ReentrancyGuard {
    IERC20 public stableCoin;
    IOracle public oracle;
    address public landlord;

    uint256 public constant LANDLORD_FEE = 15; // 1.5% in basis points
    uint256 public constant BASIS_POINTS = 1000;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake) public stakes;
    uint256 public totalStaked;

    event Staked(address indexed renter, uint256 amount);
    event Unstaked(address indexed renter, uint256 amount, uint256 reward);
    event LandlordRewardClaimed(uint256 amount);

    constructor(address _stableCoin, address _oracle, address _landlord) {
        stableCoin = IERC20(_stableCoin);
        oracle = IOracle(_oracle);
        landlord = _landlord;
    }

    function stake(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Amount must be greater than 0");
        require(stableCoin.transferFrom(msg.sender, address(this), _amount), "Transfer failed");

        if (stakes[msg.sender].amount > 0) {
            _distributeReward(msg.sender);
        }

        stakes[msg.sender].amount += _amount;
        stakes[msg.sender].timestamp = block.timestamp;
        totalStaked += _amount;

        emit Staked(msg.sender, _amount);
    }

    function unstake() external nonReentrant {
        Stake storage userStake = stakes[msg.sender];
        require(userStake.amount > 0, "No stake to unstake");

        uint256 amount = userStake.amount;
        uint256 reward = _calculateReward(msg.sender);

        uint256 landlordReward = (reward * LANDLORD_FEE) / BASIS_POINTS;
        uint256 renterReward = reward - landlordReward;

        delete stakes[msg.sender];
        totalStaked -= amount;

        require(stableCoin.transfer(msg.sender, amount + renterReward), "Transfer failed");
        require(stableCoin.transfer(landlord, landlordReward), "Landlord reward transfer failed");

        emit Unstaked(msg.sender, amount, renterReward);
        emit LandlordRewardClaimed(landlordReward);
    }

    function _distributeReward(address _renter) internal {
        uint256 reward = _calculateReward(_renter);

        uint256 landlordReward = (reward * LANDLORD_FEE) / BASIS_POINTS;
        uint256 renterReward = reward - landlordReward;

        require(stableCoin.transfer(_renter, renterReward), "Renter reward transfer failed");
        require(stableCoin.transfer(landlord, landlordReward), "Landlord reward transfer failed");

        stakes[_renter].timestamp = block.timestamp;

        emit LandlordRewardClaimed(landlordReward);
    }

    function _calculateReward(address _renter) internal view returns (uint256) {
        Stake memory userStake = stakes[_renter];
        uint256 stakingDuration = block.timestamp - userStake.timestamp;
        uint256 rewardRate = oracle.getPrice(); // Assume oracle returns APY in basis points

        return (userStake.amount * stakingDuration * rewardRate) / (365 days * BASIS_POINTS);
    }

    function getStakeInfo(address _renter) external view returns (uint256 amount, uint256 reward) {
        Stake memory userStake = stakes[_renter];
        amount = userStake.amount;
        reward = _calculateReward(_renter);
    }
}