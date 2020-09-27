pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Bifrost is ERC20("Bifrost", "BFX"), Ownable {
    using SafeMath for uint256;
    IERC20 public storm;

    // whether Bifrost is opened or not
    bool public isOpen;
    // amount of blocks between each unlock
    uint256 public blocksBetween;
    // next period that Bifrost will remain opened
    uint256[2] public openPeriod;    

    event Opened(address indexed who);
    event Closed(address indexed who);
    event Joined(address indexed who, uint256 amount);
    event Left(address indexed who, uint256 amount);

    constructor(uint256 _blocksBetween, uint256[2] memory _openPeriod, IERC20 _storm) public {
      blocksBetween = _blocksBetween;
      openPeriod = _openPeriod;
      storm = _storm;
    }

    modifier validateBifrost() {
      require(isOpen, "bifrost closed");
      _;
    }

    function pendingStorm() external view returns (uint256) {
      uint256 totalShares = totalSupply();
      if (totalShares == 0) {
        return 0;
      }

      uint256 bfxShare = balanceOf(msg.sender);
      uint256 what = bfxShare.mul(storm.balanceOf(address(this))).div(totalShares);

      return what;
    }

    function openBifrost() external {
      require(block.number > openPeriod[0] && block.number < openPeriod[1], "openBifrost: not ready to open");
      isOpen = true;

      emit Opened(msg.sender);
    }

    function closeBifrost() external {
      require(block.number > openPeriod[1]);
      // adds amount of blocks until next opening (defined by governance)
      openPeriod[0] = openPeriod[1] + blocksBetween;
      // bifrost remains open for 1 day
      openPeriod[1] = openPeriod[0] + 28800;
      isOpen = false;

      emit Closed(msg.sender);
    }

    // allows governance to update blocksBetween
    function setBlocksBetween(uint256 _newValue) public onlyOwner {
      blocksBetween = _newValue;
    }

    // Opens the Bifrost and collects STORM
    function enter(uint256 _amount) public validateBifrost {
        uint256 totalStorm = storm.balanceOf(address(this));
        uint256 totalShares = totalSupply();
        if (totalShares == 0 || totalStorm == 0) {
            _mint(msg.sender, _amount);
        } else {
            uint256 what = _amount.mul(totalShares).div(totalStorm);
            _mint(msg.sender, what);
        }
        storm.transferFrom(msg.sender, address(this), _amount);

        emit Joined(msg.sender, _amount);
    }

    // Leave the bar. Claim back your STORMs.
    function leave(uint256 _share) public validateBifrost {
        uint256 totalShares = totalSupply();
        uint256 what = _share.mul(storm.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, _share);
        storm.transfer(msg.sender, what);

        emit Left(msg.sender, what);
    }
}