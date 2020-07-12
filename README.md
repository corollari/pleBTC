# pleBTC
> Yet another /[a-z]BTC/ token, featuring self-custodiality

## Protocol
The main idea behind this protocol is to adapt statechains, a mechanism originally meant as a layer 2 solution for Bitcoin, to use it for porting BTC to the ethereum network as a token (the same that tBTC does).

### Quick primer on statechains
Statechains is a semi-trusted protocol that uses a central party (referred to as CP from now on) to coordinate UTXO transfers between users.

Initially, bitcoins are moved into the system by sending them to a 2-of-2 multisig address where one of the addresses corresponds to the user and the other corresponds to CP. Also, these two parties sign a transaction that allows the user to withdraw the funds to his own wallet at any time.

Afterwards, when the user wants to send that UTXO to some other user, the following protocol is executed:
1. User 1 notifies CP that it will transfer the UTXO to User 2
2. User 2 gives his private key to User 2
3. User 2 and CP sign a transaction that sends the funds from the multisig to an address owned only by User 2. This transaction is made to have preference over all the other previously signed transactions.

Finally, when a user wants to withdraw his bitcoins he can just broadcast the transaction created in step 3. 
You might wonder what happens if one of the previous owners broadcasts its transaction, thus trying to steal the funds from the current owner. In that case, the current owner will notice and broadcast its transactions, which, thanks to the magic of eltoo, will take preference over the first transcation broadcasted.

It is also important to note that this protocol is vulnerable to collusion between any of the previous UTXO owners and CP. This is because, if CP turns malicious, it could sign a transaction of the highest preference with one of the previous owners, thus over-powering the transaction held by the current owner, which would have a lower preference. That's the reason why this protocol is semi-trusted.

It could be argued that, because of the fact that CP collusion can be identified by public blockchain records, which would trigger a withdrawal of all the funds of the statechain, this solution might be safer than a completely centralized alternative, as CP will only be able to steal the funds for which there are colluding previous owner at a point in time, instead of all the funds. 

If you'd like to read more on it check out [this paper](https://github.com/RubenSomsen/rubensomsen.github.io/blob/master/img/statechains.pdf), although doing that shouldn't be necessary to understand pleBTC.

### Adapting the protocol for token-porting
Once we undertand how statechains work, we can create a BTC token by instantiating a new erc20 which will move in sync with the transfers being made on the statechains layer. So, essentially, all erc20 transfers will be accompanied by a private key exchange along with a new withdrawal transaction signed by CP.

This construction may seem simple, but it allows us to mitigate the main security problem that statechains have: the need to trust CP. Now that all transfers are registered on another chain it's possible to make CP create a security deposit which will be used to cover any damages caused by it's malfunction, essentially adding collateral to CP's position in a manner very similar to XCLAIM or tBTC.

Now if we take the argument that says that a CP trust breach will only lead to the theft of a part of all the funds associated with a CP and assume that it is true (or probably true), then we could set a security deposit that covers just that amount and we would end up with a trustless protocol.

Of course, that assumption is a bit of a moonshot, but, in my opinion, it should be possible to get a probabilistic bound on the percentage of money that can be stolen without having one of the previous owners blow the whistle on the conspiracy, and, in any case, this can act as yet another deterrent in a defense in depth strategy (CP federation, CP software running on AWS oracles/SGXs...).

It is also possible to make this a fully-collateralized system similar to the other /[a-z]BTC/ tokens by setting the collateralization rate higher than 100%. Such a system would have a different set of trade-offs compared to the other btc tokens, which will be analysed in the following sections.

### Poor man's eltoo
Given that the original statechains proposal is based on [eltoo](https://blockstream.com/eltoo.pdf), which requires SIGHASH\_NOINPUT, it is imperative that we use some other mechanism to handle withdrawal conflict resolution due to the fact that, as any other modern bitcoin network upgrade, we can only expect SIGHASH\_NOINPUT to be deployed [soon™](https://wowwiki.fandom.com/wiki/Soon).

There's lots of possible solutions to go for here, but the solution chosen by me here is to make the withdrawl process consist of two steps:
1. Send the money to another 2-of-2 multisign address controlled by CP and the users
2. Owner will broadcast an owner-specific transaction that can spend the UTXO created in the previous step to send it to their wallet. Each of these signed transactions will have a relative locktime which will be smaller the more recent an owner is.

In other words, we are using [BIP68](https://github.com/bitcoin/bips/blob/master/bip-0068.mediawiki) to enforce redeemability preference by having the first owner own a transaction that can be spent after 100 blocks, whereas the second owner can spend it after 90 blocks and so on. A downside of this system is that it will require users to be online at least every X hours and it will also limit the number of times a UTXO can be transferred before having to be pegged-out.

Now that the protocol, has been defined, let's go over a quick analysis of it: the good, the bad and the ugly.

## The Good
- When fully collateralized, pleBTC is more trustless than any other of the alternatives out there, such as tbtc, as it doesn't require cooperation from custodians to withdraw BTC and it relies a lot less on the assumption that the speed of change of ETH/BTC price is bounded (if that assumption is broken it doesnt mean that BTC redeemability is lost if every actor acts rationally)
- When not fully collateralized it is less capital intensive than the alternatives
- Custody is retained by the user, peg-outs are possible at any time

## The Bad
- Given that the token receiver needs to have a private key, smart contracts cannot hold pleBTC
- Users must be online at least every X hours to prevent a past owner from stealing from them (same requirement as lightning network)
- Users must be online to accept token transfers
- The amount of times a token can be transferred before pegging-out is limited
- Tokens can only be transferred in set sizes (although it should be possible to modify the protocol to add splitting transactions)
- When not fully collateralized it requires some trust on CP

## The Ugly
If CP's position is not fully collateralized, it is possible to execute the following attack:

Let's say that the collateralization rate is set to 30%, meaning that a CP attack will only be profitable if it can collude with a set of past owners that have held collectively more than 30% of the total value of the active UTXOs.

In such scenario, CP could just collude with a single past owner (eg: one that has held 10% of the active UTXOs) and port over to the statechain an amount of btc equal or higher than 30% of the total. After committing the theft, CP can just claim that the 30% of coins that it owns have also been stolen, so the 30% in collateral would be split between that 30% of falsely-stolen coins and the 10% of actually-stolen ones, thus turning a profit for CP.

As you can see, this attack completely destroys the assumption that CP would need to convince X% of the past owners to make theft profitable, as it can insert itself as a past owner and make all attacks profitable.

## Conclusions
Overall, I think that the set of trade-offs made under full-collateralization leads to a product that is less usable than other alternatives such as tBTC or sBTC, and a partially-collateralized system, which from my point of view would be better than the alternatives mentioned, fails to deliver due to the attack explained previously, so, overall, I personally don't think that pleBTC is better than other tokenization strategies.

However, I hope that this project will inspire other people to search for solutions that aren't mostly based on collateralization and lead them to start exploring the design space that opens up once you stop looking at bitcoin as something that can only be used to send money from and to a public key address.
For example, I think there's lots of interesting solutions that make use of [covenants](bitcoincovenants.com), and I'm specially pumped over the idea of building a no-fork-required [drivechains based on covenants](https://gist.github.com/corollari/0da107093fd21d49cefddab268386cec).

Also, it'd be great if someone could find a solution to the problem described in `The ugly` section, which I believe exists but I haven't been able to come up with it.

Furthermore, the protocol described here could be actually used as a layer 2 solution for bitcoin, so maybe there's something worth investigating there (other than sidechains).

## Improvements
- Currently there is no incentive against previous owners broadcasting their transactions, what's more, they are incentivized to do so because either they will lose nothing if the legitimate owner overrides their transaction or they will steal the tx if no newer transactions are broadcasted, essentially making it so the expectation of doing such an action is always >=0. This is quite bad because it leads to griefing for the current token owners, as it will force them to always peg-out even if they don't want to.
This incentive problem could be solved by making the withdrawal transactions include an additional input owned by the withdrawer which will be used as the transaction fee. This can be done by having the CP sign a transaction with both inputs using the SIGHASH\_ALL flag, which would make it impossible to spend one input without the other.
- A big part of the protocol could be moved off-chain easily (on-chain may only be needed when there are conflicts, although this requires more research).
- Replace the current spv system with nipopows embedded into the bitcoin network through a velvet fork, thus making the spv inclusion proofs much smaller (O(log n) instead of O(n)).
- Replace the current decrementing-locktime system with a Decker-Wattenhofer transform (see [this paper](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC6124062/)). Another alternative could be to replace it with a system that uses absolute timelocks, which would remove th requirement on the user to be online.
- Design some incentives to prevent owners from cooperating with CP.
- Set the amount of collateral with a function that takes into account the past owner distribution of active UTXOs. This would require some sort of identity management to make it hard for an owner to pose as two separate entities, eg: make every owner lock some collateral (this could also be used to incentivize owners not to collude with CP).

- Minimize the trust on CP by using the 2P MPC protocol described [here](https://lists.linuxfoundation.org/pipermail/bitcoin-dev/2020-March/017714.html). This MPC protocol should make it so that CP can only collude with past owners that have held the coins since the CP became malicious. That is, if a particular UTXO has the following ownership track:

| Owner | Time (day) |
|-------|------------|
| A     | 1 - 10     |
| B     | 10 - 22    |
| C     | 22 - now   |

And CP was following the protocol until day 12, then CP would only be able to collude with owners B and C.

