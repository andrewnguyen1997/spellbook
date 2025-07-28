{{ config(
        schema='prices',
        alias = 'tokens',
        materialized='table',
        file_format = 'delta',
        tags = ['static'],
        post_hook = '{{ expose_spells(\'[
                                        "abstract"
                                        , "apechain"
                                        , "arbitrum"
                                        , "avalanche_c"
                                        , "base"
                                        , "berachain"
                                        , "bitcoin"
                                        , "blast"
                                        , "bnb"
                                        , "boba"
                                        , "cardano"
                                        , "celo"
                                        , "corn"
                                        , "degen"
                                        , "ethereum"
                                        , "fantom"
                                        , "flare"
                                        , "gnosis"
                                        , "hemi"
                                        , "ink"
                                        , "katana"
                                        , "kaia"
                                        , "lens"
                                        , "linea"
                                        , "mantle"
                                        , "nova"
                                        , "opbnb"
                                        , "optimism"
                                        , "plume"
                                        , "polygon"
                                        , "ronin"
                                        , "scroll"
                                        , "sei"
                                        , "shape"
                                        , "solana"
                                        , "sonic"
                                        , "sophon"
                                        , "superseed"
                                        , "taiko"
                                        , "unichain"
                                        , "viction"
                                        , "worldchain"
                                        , "zkevm"
                                        , "zksync"
                                        , "zora"
                                    ]\',
                                    "sector",
                                    "prices",
                                    \'["aalan3", "jeff-dude", "umer_h_adil", "0xBoxer", "rantum", "lgingerich", "hildobby", "cryptokoryo", "0xRob", "hosuke", "Henrystats"]\') }}'
        )
}}

{% set evm_models = [
    ref('prices_abstract_tokens')
    ,ref('prices_apechain_tokens')
    ,ref('prices_arbitrum_tokens')
    ,ref('prices_avalanche_c_tokens')
    ,ref('prices_base_tokens')
    ,ref('prices_berachain_tokens')
    ,ref('prices_bnb_tokens')
    ,ref('prices_blast_tokens')
    ,ref('prices_boba_tokens')
    ,ref('prices_celo_tokens')
    ,ref('prices_corn_tokens')
    ,ref('prices_ethereum_tokens')
    ,ref('prices_fantom_tokens')
    ,ref('prices_flare_tokens')
    ,ref('prices_gnosis_tokens')
    ,ref('prices_hemi_tokens')
    ,ref('prices_ink_tokens')
    ,ref('prices_katana_tokens')
    ,ref('prices_kaia_tokens')
    ,ref('prices_linea_tokens')
    ,ref('prices_mantle_tokens')
    ,ref('prices_nova_tokens')
    ,ref('prices_opbnb_tokens')
    ,ref('prices_optimism_tokens')
    ,ref('prices_plume_tokens')
    ,ref('prices_polygon_tokens')
    ,ref('prices_ronin_tokens')
    ,ref('prices_scroll_tokens')
    ,ref('prices_sei_tokens')
    ,ref('prices_shape_tokens')
    ,ref('prices_sonic_tokens')
    ,ref('prices_sophon_tokens')
    ,ref('prices_superseed_tokens')
    ,ref('prices_taiko_tokens')
    ,ref('prices_unichain_tokens')
    ,ref('prices_viction_tokens')
    ,ref('prices_worldchain_tokens')
    ,ref('prices_zkevm_tokens')
    ,ref('prices_zksync_tokens')
    ,ref('prices_zora_tokens')
] %}

{% set non_evm_models = [
    ref('prices_bitcoin_tokens')
    ,ref('prices_cardano_tokens')
    ,ref('prices_degen_tokens')
    ,ref('prices_lens_tokens')
    ,ref('prices_solana_tokens')
    ,ref('prices_tron_tokens')
] %}

with native as (
    -- handle native separately due to unique use case with null blockchain/address
    select
        n.token_id
        , db.name as blockchain
        , db.token_address as contract_address
        , db.token_symbol as symbol
        , db.token_decimals as decimals
    from
        {{ ref('prices_native_tokens') }} as n
    inner join
        {{ source('dune', 'blockchains') }} as db
        on n.symbol = db.token_symbol
)
, fungible_non_evm as (
    -- source all non-EVM chains excluded from prices pipeline
    {% for model in non_evm_models -%}
    select
        token_id
        , blockchain
        , contract_address
        , symbol
        , decimals
    from
        {{ model }}
    -- unclear if needed, revisit if dupes due to native handled separate
    -- left join dune.blockchains as anti
    --     on anti.name = p.blockchain
    --     and anti.token_address = p.contract_address
    where
        contract_address is distinct from 0x0000000000000000000000000000000000000000 -- safeguard as native tokens currently have null address
    {% if not loop.last -%}
    union all
    {% endif -%}
    {% endfor -%}
)
, fungible_evm as (
    -- only source trusted tokens for EVM chains in prices pipeline
    {% for model in evm_models -%}
    select
        pt.token_id
        , pt.blockchain
        , pt.contract_address
        , pt.symbol
        , pt.decimals
    from
        {{ model }} as pt
    inner join
        {{ source('prices', 'trusted_tokens') }} as trusted
        on pt.blockchain = trusted.blockchain
        and pt.contract_address = trusted.contract_address
    -- unclear if needed, revisit if dupes due to native handled separate
    -- left join dune.blockchains as anti
    --     on anti.name = p.blockchain
    --     and anti.token_address = p.contract_address
    where
        pt.contract_address is distinct from 0x0000000000000000000000000000000000000000 -- safeguard as native tokens currently have null address
    {% if not loop.last -%}
    union all
    {% endif -%}
    {% endfor -%}
)
, final as (
    select * from native
    union all
    select * from fungible_non_evm
    union all
    select * from fungible_evm
)
select
    *
from
    final