const BN = require("bn.js");
const chai = require("chai");
const { expect, assert } = require("chai");
const expectRevert = require("./utils/expectRevert.js");
chai.use(require("chai-bn")(BN));


const PRIZE = artifacts.require('PRZ');
const PION = artifacts.require('UFragments');

const DECIMALS = new BN(9);
const TOKEN_AMOUNT = new BN((10 ** DECIMALS).toString());
const INITIAL_SUPPLY = (new BN(11 * 10 ** 6)).mul(new BN(10 ** DECIMALS));
const FEE = new BN(2);
const FEE_DECIMALS = new BN(100);

contract(
    'Prize-test',
    ([
        owner,
        customer1,
        customer2
    ]) => {
        let Pion;
        let Prize;


        beforeEach(async () => {
            // Init contracts

            Pion = await PION.new(owner, {from: owner});

            Prize = await PRIZE.new(Pion.address, {from: owner});

            await Pion.setPrizeAddr(Prize.address);
        })

        it("#0 Deploy test", async () => {
            expect(await Pion.name()).to.be.equals("Pion");
            expect(await Pion.symbol()).to.be.equals("PION");
            expect(await Pion.decimals()).to.be.bignumber.that.equals(DECIMALS);
            expect(await Pion.totalSupply()).to.be.bignumber.that.equals(INITIAL_SUPPLY);
            expect(await Pion.owner()).to.be.equals(owner);
            expect(await Pion.balanceOf(owner)).to.be.bignumber.that.equals(INITIAL_SUPPLY);

            expect(await Prize.name()).to.be.equals("Prize");
            expect(await Prize.symbol()).to.be.equals("PRIZE");
            expect(await Prize.decimals()).to.be.bignumber.that.equals(DECIMALS);
            expect(await Prize.totalSupply()).to.be.bignumber.that.equals(new BN(0));
            expect(await Prize.owner()).to.be.equals(owner);
            expect(await Prize.balanceOf(owner)).to.be.bignumber.that.equals(new BN(0));
            expect(await Prize.erc20()).to.be.equals(Pion.address);
        })

        it("#1 Test buy prize tokens + rebase", async () => {
            let pionBalanceBefore = await Pion.balanceOf(owner);

            await Pion.approve(Prize.address, TOKEN_AMOUNT, {from: owner});
            await Prize.buy(TOKEN_AMOUNT, {from: owner});

            let pionFee = TOKEN_AMOUNT.mul(FEE).div(FEE_DECIMALS);
            let prizeBalanceOwner = TOKEN_AMOUNT.sub(pionFee);
            let pionBalanceAfter = await Pion.balanceOf(owner);

            expect(await Prize.totalSupply()).to.be.bignumber.that.equals(prizeBalanceOwner);
            expect(await Prize.balanceOf(owner)).to.be.bignumber.that.equals(prizeBalanceOwner);

            expect(pionBalanceBefore.sub(pionBalanceAfter)).to.be.bignumber.that.equals(TOKEN_AMOUNT);

            // customer1
            await Pion.transfer(customer1, TOKEN_AMOUNT, {from: owner});
            await Pion.approve(Prize.address, TOKEN_AMOUNT, {from: customer1});
            await Prize.buy(TOKEN_AMOUNT, {from: customer1});

            pionFee = TOKEN_AMOUNT.mul(FEE).div(FEE_DECIMALS);
            let price = TOKEN_AMOUNT.mul(new BN(1000000000)).div(prizeBalanceOwner);
            let prizeBalanceCustomer1 = (TOKEN_AMOUNT.sub(pionFee)).mul(new BN(1000000000)).div(price);

            expect(await Prize.totalSupply()).to.be.bignumber.that.equals(prizeBalanceOwner.add(prizeBalanceCustomer1));
            expect(await Prize.balanceOf(customer1)).to.be.bignumber.that.equals(prizeBalanceCustomer1);
            expect(await Pion.balanceOf(customer1)).to.be.bignumber.that.equals(new BN(0));
            expect(await Prize.totalPionBalance()).to.be.bignumber.that.equals(TOKEN_AMOUNT.mul(new BN(2)));

            // customer2
            await Pion.transfer(customer2, TOKEN_AMOUNT, {from: owner});
            await Pion.approve(Prize.address, TOKEN_AMOUNT, {from: customer2});
            await Prize.buy(TOKEN_AMOUNT, {from: customer2});

            pionFee = TOKEN_AMOUNT.mul(FEE).div(FEE_DECIMALS);
            price = TOKEN_AMOUNT.mul(new BN(2)).mul(new BN(1000000000)).div(prizeBalanceOwner.add(prizeBalanceCustomer1));
            let prizeBalanceCustomer2 = (TOKEN_AMOUNT.sub(pionFee)).mul(new BN(1000000000)).div(price);

            expect(await Prize.totalSupply()).to.be.bignumber.that.equals(prizeBalanceOwner.add(prizeBalanceCustomer1).add(prizeBalanceCustomer2));
            expect(await Prize.balanceOf(customer2)).to.be.bignumber.that.equals(prizeBalanceCustomer2);
            expect(await Pion.balanceOf(customer2)).to.be.bignumber.that.equals(new BN(0));
            expect(await Prize.totalPionBalance()).to.be.bignumber.that.equals(TOKEN_AMOUNT.mul(new BN(3)));

            // rebase / 2
            let ownerPionBalanceBefore = await Prize.pionBalanceOfNoFee(owner);
            let customer1PionBalanceBefore = await Prize.pionBalanceOfNoFee(customer1);
            let customer2PionBalanceBefore = await Prize.pionBalanceOfNoFee(customer2);
            await Pion.rebase(1, INITIAL_SUPPLY.div(new BN(2)).mul(new BN(-1)));
            let ownerPionBalanceAfter = await Prize.pionBalanceOfNoFee(owner);
            let customer1PionBalanceAfter = await Prize.pionBalanceOfNoFee(customer1);
            let customer2PionBalanceAfter = await Prize.pionBalanceOfNoFee(customer2);

            expect(ownerPionBalanceBefore.sub(ownerPionBalanceAfter)).to.be.bignumber.that.equals(new BN(0));//.div(new BN(2)));
            expect(customer1PionBalanceBefore.sub(customer1PionBalanceAfter)).to.be.bignumber.that.equals(new BN(0));//.div(new BN(2)));
            expect(customer2PionBalanceBefore.sub(customer2PionBalanceAfter)).to.be.bignumber.that.equals(new BN(0));//.div(new BN(2)));

            // rebase * 2
            ownerPionBalanceBefore = await Prize.pionBalanceOfNoFee(owner);
            customer1PionBalanceBefore = await Prize.pionBalanceOfNoFee(customer1);
            customer2PionBalanceBefore = await Prize.pionBalanceOfNoFee(customer2);
            await Pion.rebase(1, (await Pion.totalSupply()));
            ownerPionBalanceAfter = await Prize.pionBalanceOfNoFee(owner);
            customer1PionBalanceAfter = await Prize.pionBalanceOfNoFee(customer1);
            customer2PionBalanceAfter = await Prize.pionBalanceOfNoFee(customer2);

            expect(ownerPionBalanceAfter.sub(ownerPionBalanceBefore)).to.be.bignumber.that.equals(new BN(0));
            expect(customer1PionBalanceAfter.sub(customer1PionBalanceBefore)).to.be.bignumber.that.equals(new BN(0));
            expect(customer2PionBalanceAfter.sub(customer2PionBalanceBefore)).to.be.bignumber.that.equals(new BN(0));
        })
    }
)