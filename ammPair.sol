// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * Minimal UniswapV2-style pair for TWO ERC20 tokens, with a 0.3% fee.
 * - ONE pool (fixed token0/token1 order).
 * - addLiquidity(), removeLiquidity(),
 * - getReserves(), getAmountOut(), swap().
 * SECURITY: For learning. No reentrancy guards, no LP tokens, no protocol fee.
 */

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address a) external view returns (uint256);
    function transfer(address to, uint256 v) external returns (bool);
    function transferFrom(address f, address t, uint256 v) external returns (bool);
    function allowance(address o, address s) external view returns (uint256);
    function approve(address s, uint256 v) external returns (bool);
    function decimals() external view returns (uint8);
}

contract AmmPair {
    address public immutable token0;
    address public immutable token1;

    uint112 private reserve0; // token0 reserve
    uint112 private reserve1; // token1 reserve
    uint32  private blockTimestampLast;

    event Sync(uint112 r0, uint112 r1);
    event AddLiquidity(address indexed provider, uint amount0, uint amount1);
    event Swap(address indexed trader, address tokenIn, uint amountIn, address tokenOut, uint amountOut);

    error InvalidToken();
    error InsufficientLiquidity();
    error InsufficientInput();
    error TransferFailed();

    constructor(address _token0, address _token1) {
        require(_token0 != _token1, "identical");
        // order addresses (like Uniswap) so token0 < token1
        (address a, address b) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        token0 = a;
        token1 = b;
    }

    function _update(uint256 bal0, uint256 bal1) private {
        require(bal0 <= type(uint112).max && bal1 <= type(uint112).max, "overflow");
        reserve0 = uint112(bal0);
        reserve1 = uint112(bal1);
        blockTimestampLast = uint32(block.timestamp);
        emit Sync(reserve0, reserve1);
    }

    function getReserves() public view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, blockTimestampLast);
    }

    // Add liquidity by transferring exact token0 and token1 amounts in.
    function addLiquidity(uint256 amount0, uint256 amount1) external {
        // pull tokens from sender
        if (!IERC20(token0).transferFrom(msg.sender, address(this), amount0)) revert TransferFailed();
        if (!IERC20(token1).transferFrom(msg.sender, address(this), amount1)) revert TransferFailed();

        // update reserves
        (uint112 r0, uint112 r1,) = getReserves();
        uint256 bal0 = uint256(r0) + amount0;
        uint256 bal1 = uint256(r1) + amount1;
        _update(bal0, bal1);

        emit AddLiquidity(msg.sender, amount0, amount1);
    }

    // Constant product with 0.3% fee (like UniswapV2: 997/1000)
    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientInput();
        (uint112 r0, uint112 r1,) = getReserves();
        if (r0 == 0 || r1 == 0) revert InsufficientLiquidity();

        bool inIs0 = tokenIn == token0;
        bool inIs1 = tokenIn == token1;
        if (!inIs0 && !inIs1) revert InvalidToken();

        (uint256 reserveIn, uint256 reserveOut) = inIs0 ? (r0, r1) : (r1, r0);

        uint256 amountInWithFee = amountIn * 997; // 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    // Swap exact tokens for the other side. tokenIn must be token0 or token1.
    function swapExact(address tokenIn, uint256 amountIn, uint256 minAmountOut, address to) external returns (uint256 out) {
        out = getAmountOut(tokenIn, amountIn);
        require(out >= minAmountOut, "slippage");

        if (tokenIn == token0) {
            // pull token0 in and send token1 out
            if (!IERC20(token0).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();
            if (!IERC20(token1).transfer(to, out)) revert TransferFailed();
        } else if (tokenIn == token1) {
            if (!IERC20(token1).transferFrom(msg.sender, address(this), amountIn)) revert TransferFailed();
            if (!IERC20(token0).transfer(to, out)) revert TransferFailed();
        } else {
            revert InvalidToken();
        }

        // update reserves to actual balances
        uint256 bal0 = IERC20(token0).balanceOf(address(this));
        uint256 bal1 = IERC20(token1).balanceOf(address(this));
        _update(bal0, bal1);

        emit Swap(msg.sender, tokenIn, amountIn, tokenIn == token0 ? token1 : token0, out);
    }
}
