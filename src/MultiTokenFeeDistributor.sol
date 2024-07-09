// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "src/Interfaces/IVeToken.sol";
import "src/Storage/MultiTokenFeeDistributorSchema.sol";
import "src/Storage/Storage.sol";

contract MultiTokenFeeDistributor is Initializable, ReentrancyGuardUpgradeable {
    uint256 public constant WEEK = 7 days;

    event CommitAdmin(address indexed admin);
    event ApplyAdmin(address indexed admin);
    event ToggleAllowCheckpointToken(bool toggleFlag);
    event CheckpointToken(
        address indexed tokenAddress,
        uint256 time,
        uint256 tokens
    );
    event Claimed(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amount,
        uint256 claimEpoch,
        uint256 maxEpoch
    );

    /***
     * @notice Contract constructor
     * @param votingEscrow_ VotingEscrow contract address
     * @param startTime_ Epoch time for fee distribution to start
     * @param token_ Fee token address (3CRV)
     * @param admin_ Admin address
     * @param emergencyReturn_ Address to transfer `_token` balance to if this contract is killed
     */
    function initialize(
        address votingEscrow_,
        uint256 startTime_,
        address admin_,
        address emergencyReturn_
    ) public initializer {
        __ReentrancyGuard_init();

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        uint256 t = (startTime_ / WEEK) * WEEK;
        $.startTime = t;
        $.timeCursor = t;
        $.votingEscrow = votingEscrow_;
        $.admin = admin_;
        $.emergencyReturn = emergencyReturn_;
    }

    function _checkpointToken(address tokenAddress_) internal {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];
        uint256 _tokenBalance = IERC20(tokenAddress_).balanceOf(address(this));
        // tokenDataマッピングを使用して、トークンごとの状態を取得
        uint256 _toDistribute = _tokenBalance - $token.tokenLastBalance;
        $token.tokenLastBalance = _tokenBalance;

        uint256 _t = $token.lastTokenTime;
        uint256 _sinceLast = block.timestamp - _t;
        $token.lastTokenTime = block.timestamp;
        uint256 _thisWeek = (_t / WEEK) * WEEK;
        uint256 _nextWeek = 0;

        for (uint256 i; i < 20; ) {
            _nextWeek = _thisWeek + WEEK;
            if (block.timestamp < _nextWeek) {
                if (_sinceLast == 0 && block.timestamp == _t) {
                    $token.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $token.tokensPerWeek[_thisWeek] +=
                        (_toDistribute * (block.timestamp - _t)) /
                        _sinceLast;
                }
                break;
            } else {
                if (_sinceLast == 0 && _nextWeek == _t) {
                    $token.tokensPerWeek[_thisWeek] += _toDistribute;
                } else {
                    $token.tokensPerWeek[_thisWeek] +=
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

        emit CheckpointToken(tokenAddress_, block.timestamp, _toDistribute);
    }

    /***
     * @notice Update the token checkpoint
     * @dev Calculates the total number of tokens to be distributed in a given week.
         During setup for the initial distribution this function is only callable
         by the contract owner. Beyond initial distro, it can be enabled for anyone
         to call.
     */
    function checkpointToken(address tokenAddress_) external {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];

        require(
            msg.sender == $.admin ||
                ($.canCheckpointToken &&
                    block.timestamp > $token.lastTokenTime + 1 hours),
            "Unauthorized"
        );
        _checkpointToken(tokenAddress_);
    }

    function _findTimestampEpoch(
        address ve_,
        uint256 timestamp_
    ) internal view returns (uint256) {
        uint256 _min = 0;
        uint256 _max = IVeToken(ve_).epoch();

        unchecked {
            for (uint256 i; i < 128; i++) {
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
        uint256 _min = 0;
        uint256 _max = maxUserEpoch_;

        unchecked {
            for (uint256 i; i < 128; i++) {
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
     * @notice Get the veYNWK balance for `user_` at `timestamp_`
     * @param user_ Address to query balance for
     * @param timestamp_ Epoch time
     * @return uint256 veYNWK balance
     */
    function veForAt(
        address user_,
        uint256 timestamp_
    ) external view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

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
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
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
                int128 _dt = 0;
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
     * @notice Update the veCRV total supply checkpoint
     * @dev The checkpoint is also updated by the first claimant each new epoch week. This function may be called independently of a claim, to reduce claiming gas costs.
     */
    function checkpointTotalSupply() external {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
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
                uint256 _dt = 0;
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
        address userAddress_,
        address tokenAddress_,
        address ve_,
        uint256 lastTokenTime_
    ) internal returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];

        // Minimal user_epoch is 0 (if user had no point)
        uint256 _userEpoch = 0;
        uint256 _toDistribute = 0;

        uint256 _maxUserEpoch = IVeToken(ve_).userPointEpoch(userAddress_);
        uint256 _startTime = $.startTime;

        if (_maxUserEpoch == 0) {
            // No lock = no fees
            return 0;
        }

        uint256 _weekCursor = $token.timeCursorOf[userAddress_];
        if (_weekCursor == 0) {
            // Need to do the initial binary search
            _userEpoch = _findTimestampUserEpoch(
                ve_,
                userAddress_,
                _startTime,
                _maxUserEpoch
            );
        } else {
            _userEpoch = $token.userEpochOf[userAddress_];
        }

        if (_userEpoch == 0) {
            _userEpoch = 1;
        }

        FeeDistributorSchema.Point memory _userPoint = IVeToken(ve_)
            .userPointHistory(userAddress_, _userEpoch);

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
                _userEpoch += 1;
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
                        userAddress_,
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
                        (uint256(_balanceOf) *
                            $token.tokensPerWeek[_weekCursor]) /
                        $.veSupply[_weekCursor];
                }
                _weekCursor += WEEK;
            }
            unchecked {
                ++i;
            }
        }

        _userEpoch = Math.min(_maxUserEpoch, _userEpoch - 1);
        $token.userEpochOf[userAddress_] = _userEpoch;
        $token.timeCursorOf[userAddress_] = _weekCursor;

        emit Claimed(
            userAddress_,
            tokenAddress_,
            _toDistribute,
            _userEpoch,
            _maxUserEpoch
        );

        return _toDistribute;
    }

    /***
     * @notice Claim fees for `msg.sender`
     * @dev Each call to claim look at a maximum of 50 user veCRV points.
         For accounts with many veCRV related actions, this function
         may need to be called more than once to claim all available
         fees. In the `Claimed` event that fires, if `claim_epoch` is
         less than `max_epoch`, the account may claim again.
     * @return uint256 Amount of fees claimed in the call
     */
    function claim(
        address tokenAddress_
    ) external nonReentrant returns (uint256) {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];

        require(!$.isKilled, "Contract is killed");

        address _userAddress = msg.sender;
        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $token.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken(tokenAddress_);
            _lastTokenTime = block.timestamp;
        }

        unchecked {
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        }

        uint256 _amount = _claim(
            _userAddress,
            tokenAddress_,
            $.votingEscrow,
            _lastTokenTime
        );
        if (_amount != 0) {
            require(
                IERC20(tokenAddress_).transfer(_userAddress, _amount),
                "Transfer failed"
            );
            $token.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /***
     * @notice Claim fees for `addr_`
     * @dev Each call to claim look at a maximum of 50 user veCRV points.
         For accounts with many veCRV related actions, this function
         may need to be called more than once to claim all available
         fees. In the `Claimed` event that fires, if `claim_epoch` is
         less than `max_epoch`, the account may claim again.
     * @param addr_ Address to claim fees for
     * @return uint256 Amount of fees claimed in the call
     */
    function claim(
        address userAddress_,
        address tokenAddress_
    ) external nonReentrant returns (uint256) {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];

        require(!$.isKilled, "Contract is killed");

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $token.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken(tokenAddress_);
            _lastTokenTime = block.timestamp;
        }

        unchecked {
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        }

        uint256 _amount = _claim(
            userAddress_,
            tokenAddress_,
            $.votingEscrow,
            _lastTokenTime
        );
        if (_amount != 0) {
            require(
                IERC20(tokenAddress_).transfer(userAddress_, _amount),
                "Transfer failed"
            );
            $token.tokenLastBalance -= _amount;
        }

        return _amount;
    }

    /***
     * @notice Make multiple fee claims in a single call
     * @dev Used to claim for many accounts at once, or to make
         multiple claims for the same address when that address
         has significant veCRV history
     * @param receivers_ List of addresses to claim for. Claiming
                      terminates at the first `ZERO_ADDRESS`.
     * @return bool success
     */
    function claimMany(
        address[] memory receivers_,
        address tokenAddress_
    ) external nonReentrant returns (bool) {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];
        require(!$.isKilled, "Contract is killed");

        if (block.timestamp >= $.timeCursor) {
            _checkpointTotalSupply();
        }

        uint256 _lastTokenTime = $token.lastTokenTime;

        if (
            $.canCheckpointToken && (block.timestamp > _lastTokenTime + 1 hours)
        ) {
            _checkpointToken(tokenAddress_);
            _lastTokenTime = block.timestamp;
        }

        _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;
        uint256 _total = 0;
        uint256 _l = receivers_.length;
        for (uint256 i; i < _l; ) {
            address _userAddress = receivers_[i];
            if (_userAddress == address(0)) {
                break;
            }

            uint256 _amount = _claim(
                _userAddress,
                tokenAddress_,
                $.votingEscrow,
                _lastTokenTime
            );
            if (_amount != 0) {
                require(
                    IERC20(tokenAddress_).transfer(_userAddress, _amount),
                    "Transfer failed"
                );
                _total += _amount;
            }
            unchecked {
                ++i;
            }
        }

        if (_total != 0) {
            $token.tokenLastBalance -= _total;
        }

        return true;
    }

    function claimMultipleTokens(
        address[] calldata tokenAddresses
    ) external nonReentrant returns (bool) {
        require(tokenAddresses.length > 0, "No tokens provided");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        require(!$.isKilled, "Contract is killed");

        address userAddress = msg.sender;

        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address tokenAddress = tokenAddresses[i];
            require(_isTokenPresent(tokenAddress), "Token not found");

            if (block.timestamp >= $.timeCursor) {
                _checkpointTotalSupply();
            }

            uint256 _lastTokenTime = $.tokenData[tokenAddress].lastTokenTime;
            if (
                $.canCheckpointToken &&
                (block.timestamp > _lastTokenTime + 1 hours)
            ) {
                _checkpointToken(tokenAddress);
                _lastTokenTime = block.timestamp;
            }

            // Adjust lastTokenTime to the start of the current week
            _lastTokenTime = (_lastTokenTime / WEEK) * WEEK;

            uint256 amount = _claim(
                userAddress,
                tokenAddress,
                $.votingEscrow,
                _lastTokenTime
            );
            if (amount > 0) {
                require(
                    IERC20(tokenAddress).transfer(userAddress, amount),
                    "Transfer failed"
                );
                $.tokenData[tokenAddress].tokenLastBalance -= amount;
            }
        }

        return true;
    }

    /***
     * @notice Receive 3CRV into the contract and trigger a token checkpoint
     * @param coin_ Address of the coin being received (must be 3CRV)
     * @return bool success
     */
    function burn(address tokenAddress_) external returns (bool) {
        require(_isTokenPresent(tokenAddress_), "Invalid token");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        MultiTokenFeeDistributorSchema.TokenData storage $token = $.tokenData[
            tokenAddress_
        ];

        require(!$.isKilled, "Contract is killed");

        uint256 _amount = IERC20(tokenAddress_).balanceOf(msg.sender);
        if (_amount > 0) {
            IERC20(tokenAddress_).transferFrom(
                msg.sender,
                address(this),
                _amount
            );
            if (
                $.canCheckpointToken &&
                block.timestamp > $token.lastTokenTime + 1 hours
            ) {
                _checkpointToken(tokenAddress_);
            }
        }
        return true;
    }

    function addToken(address tokenAddress_) external onlyAdmin {
        require(!_isTokenPresent(tokenAddress_), "Token already added");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        $.tokens.push(tokenAddress_);
    }

    function removeToken(address tokenAddress_) external onlyAdmin {
        require(_isTokenPresent(tokenAddress_), "Token not found");

        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        int256 tokenIndex = -1;
        for (uint256 i = 0; i < $.tokens.length; i++) {
            if ($.tokens[i] == tokenAddress_) {
                tokenIndex = int256(i);
                break;
            }
        }

        require(tokenIndex != -1, "Token not found");

        // 最後の要素を削除するトークンの位置に移動
        if (uint256(tokenIndex) < $.tokens.length - 1) {
            $.tokens[uint256(tokenIndex)] = $.tokens[$.tokens.length - 1];
        }

        // 配列の最後の要素を削除
        $.tokens.pop();
    }

    /***
     * @notice Commit transfer of ownership
     * @param addr_ New admin address
     */
    function commitAdmin(address addr_) external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        $.futureAdmin = addr_;
        emit CommitAdmin(addr_);
    }

    /***
     * @notice Apply transfer of ownership
     */
    function applyAdmin() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        require($.futureAdmin != address(0), "No admin set");
        $.admin = $.futureAdmin;
        emit ApplyAdmin($.futureAdmin);
    }

    /***
     * @notice Toggle permission for checkpointing by any account
     */
    function toggleAllowCheckpointToken() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        $.canCheckpointToken = !$.canCheckpointToken;
        emit ToggleAllowCheckpointToken($.canCheckpointToken);
    }

    /***
     * @notice Kill the contract
     * @dev Killing transfers the entire 3CRV balance to the emergency return address
         and blocks the ability to claim or burn. The contract cannot be unkilled.
     */
    function killMe() external onlyAdmin {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        $.isKilled = true;

        // 全てのトークンのバランスをemergencyReturnに転送
        for (uint256 i = 0; i < $.tokens.length; i++) {
            address tokenAddress = $.tokens[i];
            uint256 balance = IERC20(tokenAddress).balanceOf(address(this));
            if (balance > 0) {
                require(
                    IERC20(tokenAddress).transfer($.emergencyReturn, balance),
                    "Transfer failed"
                );
            }
        }
    }

    /***
     * @notice Recover ERC20 tokens from this contract
     * @dev Tokens are sent to the emergency return address.
     * @param coin_ Token address
     * @return bool success
     */
    function recoverBalance(
        address tokenAddress_
    ) external onlyAdmin returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        require(_isTokenPresent(tokenAddress_), "Cannot recover this token");

        uint256 _amount = IERC20(tokenAddress_).balanceOf(address(this));
        require(
            IERC20(tokenAddress_).transfer($.emergencyReturn, _amount),
            "Transfer failed"
        );
        return true;
    }

    function isTokenPresent(address tokenAddress) external view returns (bool) {
        return _isTokenPresent(tokenAddress);
    }

    function _isTokenPresent(
        address tokenAddress_
    ) internal view returns (bool) {
        require(tokenAddress_ != address(0), "Invalid token address");
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        for (uint256 i = 0; i < $.tokens.length; i++) {
            if ($.tokens[i] == tokenAddress_) {
                return true;
            }
        }
        return false;
    }

    modifier onlyAdmin() {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();

        require($.admin == msg.sender, "Access denied");
        _;
    }

    /**
     * @notice ストレージ変数の値を取得するための関数
     */
    function startTime() public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.startTime;
    }

    function timeCursor() public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.timeCursor;
    }

    function lastTokenTime(address tokenAddress) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress].lastTokenTime;
    }

    function tokenLastBalance(
        address tokenAddress
    ) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress].tokenLastBalance;
    }

    function canCheckpointToken() public view returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.canCheckpointToken;
    }

    function isKilled() public view returns (bool) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.isKilled;
    }

    function votingEscrow() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.votingEscrow;
    }

    function tokens() public view returns (address[] memory) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokens;
    }

    function admin() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.admin;
    }

    function futureAdmin() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.futureAdmin;
    }

    function emergencyReturn() public view returns (address) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.emergencyReturn;
    }

    function timeCursorOf(
        address tokenAddress,
        address user
    ) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress].timeCursorOf[user];
    }

    function userEpochOf(
        address tokenAddress,
        address user
    ) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress].userEpochOf[user];
    }

    function tokensPerWeek(
        address tokenAddress,
        uint256 week
    ) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.tokenData[tokenAddress].tokensPerWeek[week];
    }

    function veSupply(uint256 week) public view returns (uint256) {
        MultiTokenFeeDistributorSchema.Storage storage $ = Storage
            .MultiTokenFeeDistributor();
        return $.veSupply[week];
    }
}
