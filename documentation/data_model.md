# Data Model

The diagram below shows the relationships among the application's Active Record models.

```mermaid
erDiagram
    USER ||--o{ SESSION : has
    USER ||--o{ CART : has
    USER ||--o{ CERTIFICATE : owns

    USER ||--o| AFFILIATE_APPLICATION : submits
    USER o|--o{ AFFILIATE_APPLICATION : reviews

    USER o|--o{ AFFILIATE_INVITATION : sends
    USER o|--o| AFFILIATE_INVITATION : accepts

    USER ||--o{ USER : refers

    CART ||--o{ CERTIFICATE_PRODUCT : contains
    CART ||--o{ CHECKOUT_SESSION : has

    CERTIFICATE ||--o{ CERTIFICATE_PRODUCT : includes
    PRODUCT ||--o{ CERTIFICATE_PRODUCT : contains
    PRODUCT ||--o{ PRICE : has

    CHECKOUT_SESSION o|--o{ CERTIFICATE_PRODUCT : includes

    SHIPPING_RATE {
        uuid id PK
    }

    USER {
        uuid id PK
        uuid referred_by_id FK
        uuid affiliate_approved_by_id FK
    }

    SESSION {
        uuid id PK
        uuid user_id FK
    }

    CART {
        uuid id PK
        uuid user_id FK
    }

    CERTIFICATE {
        uuid id PK
        uuid user_id FK
    }

    CERTIFICATE_PRODUCT {
        uuid id PK
        uuid cart_id FK
        uuid certificate_id FK
        uuid product_id FK
        uuid checkout_session_id FK
    }

    CHECKOUT_SESSION {
        uuid id PK
        uuid cart_id FK
    }

    PRODUCT {
        uuid id PK
    }

    PRICE {
        uuid id PK
        uuid product_id FK
    }

    AFFILIATE_APPLICATION {
        uuid id PK
        uuid user_id FK
        uuid affiliate_invitation_id FK
        uuid reviewed_by_id FK
    }

    AFFILIATE_INVITATION {
        uuid id PK
        uuid invited_by_id FK
        uuid accepted_by_id FK
    }
```

`ShippingRate` is included as an isolated model because it currently has no Active Record associations.
