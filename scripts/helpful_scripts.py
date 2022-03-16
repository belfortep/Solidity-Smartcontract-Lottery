

from brownie import Contract, accounts, network, config, MockV3Aggregator,VRFCoordinatorMock, LinkToken, interface

FORKED_LOCAL_ENVIRONMENTS = ["mainnet-fork", "mainnet-fork-dev"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local, ganache, hardhat,mainnet-fork, local-ganache"]

def get_account(index = None, id = None):

    if index:
        return accounts[index]
    if id:
        return accounts.load(id)

    if(
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENTS
    ):
        return accounts[0]
    
    return accounts.add(config["wallets"]["from_key"])

contract_to_mock = {
    "eth_usd_price_feed" :MockV3Aggregator,
    "vrf_coordinator" : VRFCoordinatorMock,
    "link_token" : LinkToken,
}



def get_contract(contract_name):
    contract_type = contract_to_mock[contract_name]
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        if len(contract_type) <=0 :
            deploy_mocks()
        contract = contract_type[-1]
    else:
        contract_address=config["networks"][network.show_active()][contract_name]

        contract = Contract.from_abi(contract_type._name, contract_address, contract_type.abi)
        #los objetos del mock aggregator tienen una propiedad _name y .abi
    return contract

DECIMALS=8
INITIAL_VALUE=200000000000

def deploy_mocks(decimals = DECIMALS, initial_value =INITIAL_VALUE):
    account=get_account()
    MockV3Aggregator.deploy(decimals, initial_value, {"from" : account})
    link_token = LinkToken.deploy({"from" :account})
    VRFCoordinatorMock.deploy(link_token.address, {"from" :account})
    print("deployado")

def fund_with_link(contract_address, account = None, link_token=None, amount=100000000000000000):
        account = account if account else get_account() #mi cuenta va a ser la cuenta que le pase si existe, si no utiliza el get_account
        link_token = link_token if link_token else get_contract("link_token")
        tx = link_token.transfer(contract_address, amount, {"from" :account})
        #link_token_contract = interface.LinkTokenInterface(link_token.address)
        #tx = link_token_contract.transfer(contract_address, amount, {"from" :account})
        tx.wait(1)
        print('contrato pagado con link')
        return tx
