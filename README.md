

### Uniswap Versions

- v1 ---> November 2018
One of the swapped tokens had to be the Ether.

- v2 ---> March 2020
Any pair of tokens could be swapped directly.

- v3 ---> May 2021
Improved capital efficiency.

### How it works

- In non-orderbook systems, liquidity is what allows trading to be possible.
- In Uniswap anyone can be a **market maker**, that's why it's called an **automated market maker**. Any user can deposit funds to a specific trading pair and add liquidity, and in exchange earn money for doing so through trading fees taken from the users.

#### X Y = K 

At the core of Uniswap is one math function:

`x * y = k`

Assume we have a trading pair for ETH <> CL Token

x = reserve balance of ETH in the trading pool

y = reserve balance of CL Token in the trading pool

k = a constant

Every swap made increases the reserve of either ETH or CL Token and decreases the reserve of the other.

`(x + Δx) * (y - Δy) = k`

Solving for Δy --->

`Δy = (y * Δx) / (x + Δx)`

```
function calculateOutputAmount(uint inputAmount, uint inputReserve, uint outputReserve) private pure returns (uint) {
    uint outputAmount = (outputReserve * inputAmount) / (inputReserve + inputAmount);
    return outputAmount;
}
```

The product formula we use for price calculations is actually a hyperbola.

The price function causes **slippage** in the price. The bigger the amount of tokens being traded relative to their reserve values, the lower the price would be. This mechanism protects pools from being completely drained. 

#### Adding liquidity

It involves adding tokens from both sides of the trading pair, not just one side.

```
function addLiquidity(uint256 tokenAmount) public payable {
    IERC20 token = IERC20(tokenAddress);
    token.transferFrom(msg.sender, address(this), tokenAmount);
}
```

We must ensure that anyone adding additional liquidity to the pool is doing so in the same proportion as that already established in the pool. We only want to allow arbitrary ratios when the pool is completely empty.

```
function addLiquidity(uint tokenAmount) public payable {
    // assuming a hypothetical function
    // that returns the balance of the 
    // token in the contract
    if (getReserve() == 0) {
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), tokenAmount);
    } else {
        uint ethReserve = address(this).balance - msg.value;
        uint tokenReserve = getReserve();
        uint proportionalTokenAmount = (msg.value * tokenReserve) / ethReserve;
        require(tokenAmount >= proportionalTokenAmount, "incorrect ratio of tokens provided");
        
        IERC20 token = IERC20(tokenAddress);
        token.transferFrom(msg.sender, address(this), proportionalTokenAmount);
    }
}
```

#### LP Tokens

We need a way to reward the liquidity providers for their tokens. 
The only good solution for this is to collect a small fee on each token swap and distribute the fees amongst the liquidity providers, based on how much liquidity they provided.
There is a quite elegant solution to do this: **Liquidity Provider Tokens (LP Tokens)**

LP tokens work as shares.
- Issued shares must always be correct. When someone else deposits or removes liquidity after you, your shares should remain and maintain correct values.
- Writing data to the chain can be expensive (gas fees) - we want to reduce the maintainence costs of LP-tokens as much as possible.

The only good solution seems to have no supply limit at all, and mint new tokens whenever new liquidity is added. This allows for infinite growth, and if we do the math carefully, we can make sure issued shares remain correct whenever liquidity is added or removed.

Uniswap V1 calculates the amount proportionate to the ETH reserve.

`amountMinted = totalAmount * (ethDeposited / ethReserve)`


```
function addLiquidity(uint tokenAmount) public payable {
    if (getReserve() == 0) {
        ...
        
        uint liquidity = address(this).balance;
        _mint(msg.sender, liquidity);
    } else {
        ...
        uint liquidity = (totalSupply() * msg.value) / ethReserve;
        _mint(msg.sender, liquidity);
    }
}
```

Now we have LP-tokens, we can also use them to calculate how much underlying tokens to return when someone wants to withdraw their liquidity in exchange for their LP-tokens.


