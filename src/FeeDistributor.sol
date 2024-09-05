// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "src/Interfaces/IVeToken.sol";
import "src/Storage/FeeDistributorSchema.sol";
import "src/Storage/Storage.sol";

contract FeeDistributor is Initializable, ReentrancyGuardUpgradeable {
    uint256 public constant WEEK = 7 * 86400;

    event CommitAdmin(address indexed admin);
    event ApplyAdmin(address indexed admin);
    event ToggleAllowCheckpointToken(bool toggleFlag);
    event CheckpointToken(uint256 time, uint256 tokens);
    event Claimed(
        address indexed recipient,
        uint256 amount,
        uint256 claimEpoch,
        uint256 maxEpoch
    );

    /***
     * @notice Contract constructor
     * @param votingEscrow_ VotingEscrow contract address
     * @param startTime_ Epoch time for fee distribution to start
     * @param token_ Fee token address
     * @param admin_ Admin address
     * @param emergencyReturn_ Address to transfer `_token` balance to if this contract is killed
     */
    function initialize(
        address votingEscrow_,
        uint256 startTime_,
        address token_,
        address admin_,
        address emergencyReturn_
    ) public initializer {
        __ReentrancyGuard_init();

        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        uint256 t = (startTime_ / WEEK) * WEEK;
        $.startTime = t;
        $.lastTokenTime = t;
        $.timeCursor = t;
        $.token = token_;
        $.votingEscrow = votingEscrow_;
        $.admin = admin_;
        $.emergencyReturn = emergencyReturn_;
    }

    function _checkpointToken() internal {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        uint256 _tokenBalance = IERC20($.token).balanceOf(address(this));
        uint256 _toDistribute = _tokenBalance - $.tokenLastBalance;
        $.tokenLastBalance = _tokenBalance;

        uint256 _t = $.lastTokenTime;
        uint256 _sinceLast = block.timestamp - _t;
        $.lastTokenTime = block.timestamp;
        uint256 _thisWeek = (_t / WEEK) * WEEK;
        uint256 _nextWeek;

        for (uint256 i; i < 20; ) {
            _nextWeek = _thisWeek + WEEK;
            if (block.timestamp < _nextWeek) {
                if (_sinceLast == 0 && block.timestamp == _t) {
                    $.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $.tokensPerWeek[_thisWeek] +=
                        (_toDistribute * (block.timestamp - _t)) /
                        _sinceLast;
                }
                break;
            } else {
                if (_sinceLast == 0 && _nextWeek == _t) {
                    $.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $.tokensPerWeek[_thisWeek] +=
                        (_toDistribute * (_nextWeek - _t)) /
                        _sinceLast;
                }
            }
            _t = _nextWeek;
            _thisWeek = _nextWeek;
            unchecked {
                ++i;
            }
        }

        emit CheckpointToken(block.timestamp, _toDistribute);
    }

    /***
     * @notice Update the token checkpoint
     * @dev Calculates the total number of tokens to be distributed in a given week.
         During setup for the initial distribution this function is only callable
         by the contract owner. Beyond initial distro, it can be enabled for anyone
         to call.
     */
    function checkpointToken() external {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        require(
            msg.sender == $.admin ||
                ($.canCheckpointToken &&
                    block.timestamp > $.lastTokenTime + 1 hours),
            "Unauthorized"
        );
        _checkpointToken();
    }

    function _findTimestampEpoch(
        address ve_,
        uint256 timestamp_
    ) internal view returns (uint256) {
        uint256 _min;
        uint256 _max = IVeToken(ve_).epoch();

        unchecked {
            for (uint256 i; i < 128; ++i) {
                if (_min >= _max) {
                    break;
                }
                uint256 _mid = (_min + _max + 2) / 2;
                FeeDistributorSchema.Point memory _pt = IVeToken(ve_)
                    .pointHistory(_mid);
                if (_pt.ts <= timestamp_) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    function _findTimestampUserEpoch(
        address ve_,
        address user_,
        uint256 timestamp_,
        uint256 maxUserEpoch_
    ) internal view returns (uint256) {
        uint256 _min;
        uint256 _max = maxUserEpoch_;

        unchecked {
            for (uint256 i; i < 128; ++i) {
                if (_min >= _max) {
                    break;
                }
                uint256 _mid = (_min + _max + 2) / 2;
                FeeDistributorSchema.Point memory _pt = IVeToken(ve_)
                    .userPointHistory(user_, _mid);
                if (_pt.ts <= timestamp_) {
                    _min = _mid;
                } else {
                    _max = _mid - 1;
                }
            }
        }
        return _min;
    }

    /***
     * @notice Get the veToken balance for `user_` at `timestamp_`
     * @param user_ Address to query balance for
     * @param timestamp_ Epoch time
     * @return uint256 veToken balance
     */
    function veForAt(
        address user_,
        uint256 timestamp_
    ) external view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        address _ve = $.votingEscrow;
        uint256 _maxUserEpoch = IVeToken(_ve).userPointEpoch(user_);
        uint256 _epoch = _findTimestampUserEpoch(
            _ve,
            user_,
            timestamp_,
            _maxUserEpoch
        );
        FeeDistributorSchema.Point memory _pt = IVeToken(_ve).userPointHistory(
            user_,
            _epoch
        );
        int128 _balance = _pt.bias -
            _pt.slope *
            int128(int256(timestamp_ - _pt.ts));
        if (_balance < 0) {
            return 0;
        } else {
            return uint256(uint128(_balance));
        }
    }

    function _checkpointTotalSupply() internal {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        address _ve = $.votingEscrow;
        uint256 _t = $.timeCursor;
        uint256 _roundedTimestamp = (block.timestamp / WEEK) * WEEK;
        IVeToken(_ve).checkpoint();

        for (uint256 i; i < 20; ) {
            if (_t > _roundedTimestamp) {
                break;
            } else {
                uint256 _epoch = _findTimestampEpoch(_ve, _t);
                FeeDistributorSchema.Point memory _pt = IVeToken(_ve)
                    .pointHistory(_epoch);
                int128 _dt;
                if (_t > _pt.ts) {
                    _dt = int128(int256(_t) - int256(_pt.ts));
                }
                $.veSupply[_t] = uint256(int256(_pt.bias - _pt.slope * _dt));
                _t += WEEK;
            }
            unchecked {
                ++i;
            }
        }

        $.timeCursor = _t;
    }

    /***
     * @notice Update the veToken total supply checkpoint
     * @dev The checkpoint is also updated by the first claimant each new epoch week. This function may be called independently of a claim, to reduce claiming gas costs.
     */
    function checkpointTotalSupply() external {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        address _ve = $.votingEscrow;
        uint256 _t = $.timeCursor;
        uint256 _roundedTimestamp = (block.timestamp / WEEK) * WEEK;
        IVeToken(_ve).checkpoint();

        for (uint256 i; i < 20; ) {
            if (_t > _roundedTimestamp) {
                break;
            } else {
                uint256 _epoch = _findTimestampEpoch(_ve, _t);
                FeeDistributorSchema.Point memory _pt = IVeToken(_ve)
                    .pointHistory(_epoch);
                uint256 _dt;
                if (_t > _pt.ts) {
                    _dt = uint256(int256(_t) - int256(_pt.ts));
                }

                int128 _balance = _pt.bias - _pt.slope * int128(int256(_dt));
                if (_balance < 0) {
                    $.veSupply[_t] = 0;
                } else {
                    $.veSupply[_t] = uint256(uint128(_balance));
                }
            }
            _t += WEEK;
            unchecked {
                ++i;
            }
        }

        $.timeCursor = _t;
    }

    function _claim(
        address addr_,
        address ve_,
        uint256 lastTokenTime_
    ) internal returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        // Minimal user_epoch is 0 (if user had no point)
        uint256 _userEpoch;
        uint256 _toDistribute;

        uint256 _maxUserEpoch = IVeToken(ve_).userPointEpoch(addr_);
        uint256 _startTime = $.startTime;

        if (_maxUserEpoch == 0) {
            // No lock = no fees
            return 0;
        }

        uint256 _weekCursor = $.timeCursorOf[addr_];
        if (_weekCursor == 0) {
            // Need to do the initial binary search
            _userEpoch = _findTimestampUserEpoch(
                ve_,
                addr_,
                _startTime,
                _maxUserEpoch
            );
        } else {
            _userEpoch = $.userEpochOf[addr_];
        }

        if (_userEpoch == 0) {
            _userEpoch = 1;
        }

        FeeDistributorSchema.Point memory _userPoint = IVeToken(ve_)
            .userPointHistory(addr_, _userEpoch);

        if (_weekCursor == 0) {
            _weekCursor = ((_userPoint.ts + WEEK - 1) / WEEK) * WEEK;
        }

        if (_weekCursor >= lastTokenTime_) {
            return 0;
        }

        if (_weekCursor < _startTime) {
            _weekCursor = _startTime;
        }

        FeeDistributorSchema.Point memory _oldUserPoint = FeeDistributorSchema
            .Point({bias: 0, slope: 0, ts: 0, blk: 0});

        // Iterate over weeks
        for (uint256 i; i < 50; ) {
            if (_weekCursor >= lastTokenTime_) {
                break;
            } else if (
                _weekCursor >= _userPoint.ts && _userEpoch <= _maxUserEpoch
            ) {
                ++_userEpoch;
                _oldUserPoint = FeeDistributorSchema.Point({
                    bias: _userPoint.bias,
                    slope: _userPoint.slope,
                    ts: _userPoint.ts,
                    blk: _userPoint.blk
                });
                if (_userEpoch > _maxUserEpoch) {
                    _userPoint = FeeDistributorSchema.Point({
                        bias: 0,
                        slope: 0,
                        ts: 0,
                        blk: 0
                    });
                } else {
                    _userPoint = IVeToken(ve_).userPointHistory(
                        addr_,
                        _userEpoch
                    );
                }
            } else {
                int256 _dt = int256(_weekCursor) - int256(_oldUserPoint.ts);
                int256 _balanceOf = int256(_oldUserPoint.bias) -
                    _dt *
                    int256(_oldUserPoint.slope);
                if (
                    int256(_oldUserPoint.bias) -
                        _dt *
                        int256(_oldUserPoint.slope) <
                    0
                ) {
                    _balanceOf = 0;
                }

                if (_balanceOf == 0 && _userEpoch > _maxUserEpoch) {
                    break;
                }
                if (_balanceOf > 0) {
                    _toDistribute +=
                        (uint256(_balanceOf) * $.tokensPerWeek[_weekCursor]) /
                        $.veSupply[_weekCursor];
                }
                _weekCursor += WEEK;
            }
            unchecked {
                ++i;
            }
        }

        _userEpoch = Math.min(_maxUserEpoch, _userEpoch - 1);
        $.userEpochOf[addr_] = _userEpoch;
        $.timeCursorOf[addr_] = _weekCursor;

        emit Claimed(addr_, _toDistribute, _userEpoch, _maxUserEpoch);

        return _toDistribute;
    }

    /***
     * @notice Claim fees for `msg.sender`
     * @dev Each call to claim look at a maximum of 50 user veToken points.
         For accounts with many veToken related actions, this function
         may need to be called more than once to claim all available
         fees. In the `Claimed` event that fires, if `claim_epoch` is
         less than `max_epoch`, the account may claim again.
     * @return uint256 Amount of fees claimed in the call
     */
    function claim() external nonReentrant returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        require(!$.isKilled, "Contract is killed");
        address _addr = msg.sender;
        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        unchecked {
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        }

        uint256 _amount = _claim(_addr, $.votingEscrow, _lastTokenTime);
        if (_amount != 0) {
            require(
                IERC20($.token).transfer(_addr, _amount),
                "Transfer failed"
            );
            $.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /***
     * @notice Claim fees for `addr_`
     * @dev Each call to claim look at a maximum of 50 user veToken points.
         For accounts with many veToken related actions, this function
         may need to be called more than once to claim all available
         fees. In the `Claimed` event that fires, if `claim_epoch` is
         less than `max_epoch`, the account may claim again.
     * @param addr_ Address to claim fees for
     * @return uint256 Amount of fees claimed in the call
     */
    function claimFor(address addr_) external nonReentrant returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        require(!$.isKilled, "Contract is killed");

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        unchecked {
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        }

        uint256 _amount = _claim(addr_, $.votingEscrow, _lastTokenTime);
        if (_amount != 0) {
            require(
                IERC20($.token).transfer(addr_, _amount),
                "Transfer failed"
            );
            $.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /***
     * @notice Make multiple fee claims in a single call
     * @dev Used to claim for many accounts at once, or to make
         multiple claims for the same address when that address
         has significant veToken history
     * @param receivers_ List of addresses to claim for. Claiming
                      terminates at the first `ZERO_ADDRESS`.
     * @return bool success
     */
    function claimMany(
        address[] memory receivers_
    ) external nonReentrant returns (bool) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        require(!$.isKilled, "Contract is killed");

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken();
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint256 _total;
        uint256 _l = receivers_.length;
        for (uint256 i; i < _l; ) {
            address _addr = receivers_[i];
            if (_addr == address(0)) {
                break;
            }

            uint256 _amount = _claim(_addr, $.votingEscrow, _lastTokenTime);
            if (_amount != 0) {
                require(
                    IERC20($.token).transfer(_addr, _amount),
                    "Transfer failed"
                );
                _total += _amount;
            }
            unchecked {
                ++i;
            }
        }

        if (_total != 0) {
            $.tokenLastBalance -= _total;
        }

        return true;
    }

    /***
     * @notice Receive Token into the contract and trigger a token checkpoint
     * @param coin_ Address of the coin being received
     * @return bool success
     */
    function burn(address coin_) external returns (bool) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        require(coin_ == address($.token), "Invalid token");
        require(!$.isKilled, "Contract is killed");

        uint256 _amount = IERC20($.token).balanceOf(msg.sender);
        if (_amount > 0) {
            IERC20($.token).transferFrom(msg.sender, address(this), _amount);
            if (
                $.canCheckpointToken &&
                block.timestamp > $.lastTokenTime + 1 hours
            ) {
                _checkpointToken();
            }
        }
        return true;
    }

    /***
     * @notice Commit transfer of ownership
     * @param addr_ New admin address
     */
    function commitAdmin(address addr_) external onlyAdmin {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        $.futureAdmin = addr_;
        emit CommitAdmin(addr_);
    }

    /***
     * @notice Apply transfer of ownership
     */
    function applyAdmin() external onlyAdmin {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        require($.futureAdmin != address(0), "No admin set");
        $.admin = $.futureAdmin;
        emit ApplyAdmin($.futureAdmin);
    }

    /***
     * @notice Toggle permission for checkpointing by any account
     */
    function toggleAllowCheckpointToken() external onlyAdmin {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        $.canCheckpointToken = !$.canCheckpointToken;
        emit ToggleAllowCheckpointToken($.canCheckpointToken);
    }

    /***
     * @notice Kill the contract
     * @dev Killing transfers the entire Token balance to the emergency return address
         and blocks the ability to claim or burn. The contract cannot be unkilled.
     */
    function killMe() external onlyAdmin {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        $.isKilled = true;
        require(
            IERC20($.token).transfer(
                $.emergencyReturn,
                IERC20($.token).balanceOf(address(this))
            ),
            "Transfer failed"
        );
    }

    /***
     * @notice Recover ERC20 tokens from this contract
     * @dev Tokens are sent to the emergency return address.
     * @param coin_ Token address
     * @return bool success
     */
    function recoverBalance(address coin_) external onlyAdmin returns (bool) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        require(coin_ != address($.token), "Cannot recover this token");

        uint256 _amount = IERC20(coin_).balanceOf(address(this));
        require(
            IERC20(coin_).transfer($.emergencyReturn, _amount),
            "Transfer failed"
        );
        return true;
    }

    modifier onlyAdmin() {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();

        require($.admin == msg.sender, "Access denied");
        _;
    }

    /**
     * @notice ストレージ変数の値を取得するための関数
     */
    function startTime() public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.startTime;
    }

    function timeCursor() public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.timeCursor;
    }

    function lastTokenTime() public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.lastTokenTime;
    }

    function totalReceived() public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.totalReceived;
    }

    function tokenLastBalance() public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.tokenLastBalance;
    }

    function canCheckpointToken() public view returns (bool) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.canCheckpointToken;
    }

    function isKilled() public view returns (bool) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.isKilled;
    }

    function votingEscrow() public view returns (address) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.votingEscrow;
    }

    function token() public view returns (address) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.token;
    }

    function admin() public view returns (address) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.admin;
    }

    function futureAdmin() public view returns (address) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.futureAdmin;
    }

    function emergencyReturn() public view returns (address) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.emergencyReturn;
    }

    function timeCursorOf(address user) public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.timeCursorOf[user];
    }

    function userEpochOf(address user) public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.userEpochOf[user];
    }

    function tokensPerWeek(uint256 week) public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.tokensPerWeek[week];
    }

    function veSupply(uint256 week) public view returns (uint256) {
        FeeDistributorSchema.Storage storage $ = Storage.FeeDistributor();
        return $.veSupply[week];
    }
}
