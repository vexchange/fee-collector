seth calldata (jq -r .bin out/FeeCollector.sol/FeeCollector.json)(string sub -s 3 (seth abi-encode "FeeCollector(address,address,address)" 0xb312582c023cc4938cf0faea2fd609b46d7509a2 0xd8ccdd85abdbf68dfec95f06c973e87b1b5a9997 0x41D293Ee2924FF67Bd934fC092Be408162448f86))
