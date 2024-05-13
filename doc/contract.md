```mermaid
graph LR;
    VeFactory-->|create|Token;
    VeFactory-->|create|veToken;
    VeFactory-->|create|veTokenCustom;
    VeFactory-->|create|Proxy;

    Dict[Dict<br>functional implementation address] -->|get implementation address| Proxy[Clone Proxy];
    Proxy -->|delegate| Minter;
    Proxy -->|delegate| FeeDistributor;
    Proxy -->|delegate| GaugeController;
    Proxy -->|delegate| Gauge;

    subgraph upgradable UUPS
      VeFactory 
    end

    subgraph no upgradable
      Token 
      veToken
      veTokenCustom
    end

    subgraph upgradable ERC7546:UCS
      Proxy
      Minter 
      FeeDistributor
      GaugeController
      Gauge
    end

