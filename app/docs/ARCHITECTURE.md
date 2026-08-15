# Orderit - Food Delivery Application Architecture

**App Name:** Orderit (Food Delivery Platform)  
**Tech Stack:** MERN (MongoDB, Express, React, Node.js)  
**Status:** Development-ready, local run verified against MongoDB Atlas

---

## System Overview

```mermaid
graph TB
    Browser["🌐 Browser<br/>(User)"]
    Frontend["Frontend<br/>(CRA + Redux)<br/>Port 3000"]
    Nginx["Nginx<br/>(Prod)"]
    Backend["Backend API<br/>(Express.js)<br/>Port 4000"]
    Mongo["MongoDB Atlas<br/>(Database)"]
    Cloudinary["Cloudinary<br/>(Image CDN)"]
    Stripe["Stripe<br/>(Payments)"]
    Email["Mailtrap/SMTP<br/>(Email Notifications)"]
    
    Browser -->|HTTP| Frontend
    Frontend -->|Proxy /api/v1/*| Backend
    Frontend -->|Build→Serve| Nginx
    Backend -->|CRUD| Mongo
    Backend -->|Upload/Fetch| Cloudinary
    Backend -->|Charge| Stripe
    Backend -->|Send| Email
    
    style Frontend fill:#61dafb
    style Backend fill:#90c53f
    style Mongo fill:#13aa52
    style Cloudinary fill:#4b90e2
    style Stripe fill:#635bff
```

---

## Backend Architecture

### Framework & Core
- **Runtime:** Node.js
- **Framework:** Express.js (4.18.2)
- **Database ORM:** Mongoose (7.2.1)
- **Authentication:** JWT (jsonwebtoken 9.0.1) + bcryptjs (2.4.3)
- **File Upload:** Multer (1.4.5) + Cloudinary SDK (1.37.3)
- **Payment Processing:** Stripe SDK (12.14.0)
- **Email:** Nodemailer (6.9.3) + Pug templates

### Directory Structure

```
backend/
├── routes/                    # API endpoint definitions
│   ├── auth.js               # POST /api/v1/users/* (register, login, reset password)
│   ├── restaurant.js         # GET /api/v1/eats/stores (list restaurants)
│   ├── menu.js              # GET /api/v1/eats/menus (menu browsing)
│   ├── foodItem.js          # GET /api/v1/eats/* (food items)
│   ├── order.js             # POST/GET /api/v1/eats/orders (order CRUD)
│   ├── payment.js           # POST /api/v1/payment (Stripe webhook)
│   ├── reviewsRoutes.js     # POST /api/v1/reviews (ratings & reviews)
│   ├── couponRoutes.js      # GET /api/v1/coupon (discount codes)
│   └── restaurant_count.js  # GET /api/v1/restaurants/count
│
├── controllers/               # Business logic per route
│   ├── authController.js     # User registration, login, password reset
│   ├── restaurantController.js # Restaurant CRUD, search
│   ├── menuController.js     # Menu management
│   ├── foodItemController.js # Food item CRUD
│   ├── orderController.js    # Order processing, tracking
│   ├── paymentController.js  # Stripe charge + webhook
│   ├── reviewController.js   # Review/rating submission
│   └── couponController.js   # Coupon validation & discount apply
│
├── models/                    # MongoDB Schemas
│   ├── user.js              # User: email, password, address, phone, avatar
│   ├── restaurant.js        # Restaurant: name, image, ratings, location
│   ├── menu.js              # Menu: items per restaurant
│   ├── foodItem.js          # FoodItem: name, price, image, description
│   ├── order.js             # Order: items, total, status, delivery address
│   ├── reviewModel.js       # Review: rating, comment, author
│   └── couponModel.js       # Coupon: code, discount%, valid date range
│
├── middlewares/              # Request/response handlers
│   ├── catchAsyncErrors.js  # Try-catch wrapper for async route handlers
│   └── errors.js            # Error formatting & HTTP status mapping
│
├── config/
│   ├── config.env           # Environment variables (port, DB URI, secrets)
│   └── database.js          # Mongoose connection setup
│
├── utils/
│   ├── seeder.js           # Database seed script (populate test data)
│   └── (other helpers)
│
├── app.js                   # Express app setup, middleware, route mounting
├── server.js                # Entry point, port listener
└── package.json             # Dependencies & scripts
```

### Key API Endpoints

| Method | Endpoint | Auth | Purpose |
|--------|----------|------|---------|
| POST | `/api/v1/users/register` | None | User registration |
| POST | `/api/v1/users/login` | None | User login (JWT) |
| POST | `/api/v1/users/password/forgot` | None | Forgot password email |
| GET | `/api/v1/eats/stores` | None | List all restaurants |
| GET | `/api/v1/eats/menus` | None | List all menus/items |
| POST | `/api/v1/eats/orders` | JWT | Create order |
| GET | `/api/v1/eats/orders/:id` | JWT | Get order details |
| POST | `/api/v1/payment` | JWT | Process Stripe payment |
| POST | `/api/v1/reviews` | JWT | Submit review |
| GET | `/api/v1/coupon/:code` | None | Validate coupon |

---

## Frontend Architecture

### Framework & State Management
- **Framework:** React 18.2.0 (Create React App)
- **State Management:** Redux 4.2.1 + Redux Thunk (side effects)
- **HTTP Client:** Axios 1.5.0
- **Routing:** React Router DOM 6.15.0
- **UI Library:** React Bootstrap 2.8.0 + MDBReact 5.2.0
- **Icons:** Font Awesome 6.4.2
- **Payments:** Stripe React Library (2.3.0)
- **Alerts:** React Alert 7.0.3

### Directory Structure (src/)

```
frontend/src/
├── actions/              # Redux action creators
│   ├── userActions.js   # Login, register, update profile
│   ├── restaurantAction.js # Fetch restaurants, filter/sort
│   ├── menuActions.js   # Fetch menus
│   ├── orderActions.js  # Create, fetch, track orders
│   └── (other domains)
│
├── reducers/            # Redux state slices
│   ├── userReducer.js
│   ├── restaurantReducer.js
│   ├── cartReducer.js
│   ├── orderReducer.js
│   └── (other domains)
│
├── components/          # Reusable React components
│   ├── Header.js       # Navigation bar, logo, user menu
│   ├── Search.js       # Restaurant search bar
│   ├── (UI components)
│
├── pages/              # Full page views
│   ├── Home.js        # Restaurant listing, filters (sort by rating/reviews)
│   ├── Registration.js # Sign up form
│   ├── Checkout.js    # Cart review, address entry, confirm order
│   ├── PaymentDetails.js # Stripe card form
│   ├── OrderSuccess.js # Confirmation page + order tracking
│   ├── MyOrders.js    # Order history, pagination, search
│   ├── OrderDetails.js # Single order view + status tracking
│   ├── ForgotPassword.js # Password reset flow
│   └── (other pages)
│
├── App.js             # Root component, routing setup
├── index.js           # React DOM mount
└── store.js           # Redux store configuration

public/
├── index.html         # HTML template
├── logo*.png          # App logo/favicon (16×16, 192×192, 512×512)
└── robots.txt         # SEO crawlers
```

### Pages & Features

| Page | Redux State | Key Features |
|------|-------------|--------------|
| Home | `restaurants`, `cart` | View restaurants, search, filter by ratings/reviews, add to cart |
| Registration | `user` | Sign up form (name, email, password, phone, avatar) |
| Checkout | `cart`, `order` | Review cart items, enter delivery address, apply coupon, confirm |
| Payment Details | `order` | Stripe card form, process charge |
| Order Success | `order` | Order confirmation, order ID, delivery tracking |
| My Orders | `orders` | Paginated list, search, status indicators |
| Order Details | `order` | Full order info, items, delivery address, tracking status |

### State Shape (Redux)

```javascript
{
  user: {
    isAuthenticated: boolean,
    loading: boolean,
    user: { id, email, name, phone, address, avatar },
    error: string | null
  },
  restaurants: {
    loading: boolean,
    restaurants: [{ id, name, image, ratings, location }, ...],
    filters: { sortBy: 'ratings' | 'reviews', vegOnly: boolean }
  },
  cart: {
    items: [{ foodItemId, quantity, price }, ...],
    subtotal: number
  },
  orders: {
    loading: boolean,
    orders: [{ id, restaurantId, items, total, status, createdAt }, ...],
    currentOrder: { ... }
  }
}
```

---

## Database Schema (MongoDB)

### User Collection
```javascript
{
  _id: ObjectId,
  name: String,
  email: String (unique),
  password: String (bcrypt hashed),
  phone: String,
  address: String,
  avatar: { public_id, url } // Cloudinary image
}
```

### Restaurant Collection
```javascript
{
  _id: ObjectId,
  name: String,
  image: { public_id, url },
  ratings: Number (avg),
  location: String,
  createdAt: Date
}
```

### Food Item Collection
```javascript
{
  _id: ObjectId,
  name: String,
  price: Number,
  image: { public_id, url },
  description: String,
  menuId: ObjectId (ref: Menu),
  restaurantId: ObjectId (ref: Restaurant)
}
```

### Order Collection
```javascript
{
  _id: ObjectId,
  userId: ObjectId (ref: User),
  restaurantId: ObjectId (ref: Restaurant),
  items: [{ foodItemId, quantity, price }, ...],
  subtotal: Number,
  deliveryCharges: Number,
  tax: Number,
  total: Number,
  deliveryAddress: String,
  status: String (pending | processing | delivered | cancelled),
  stripePaymentId: String,
  couponCode: String (optional),
  createdAt: Date,
  updatedAt: Date
}
```

---

## External Services

### MongoDB Atlas
- **Purpose:** Primary database
- **Connection:** Atlas cluster `cluster0`, database `Internship`
- **Auth:** Username/password with IP whitelist
- **Collections:** users, restaurants, menus, fooditems, orders, reviews, coupons

### Cloudinary
- **Purpose:** Image storage & CDN (user avatars, restaurant images, food photos)
- **Auth:** API key + secret in env vars
- **Response:** Public URL for each upload

### Stripe
- **Purpose:** Payment processing for orders
- **Flow:** Frontend tokenizes card → Backend charges via Stripe API → Webhook confirms
- **Auth:** Secret key for server-side charges (never exposed to client)

### Mailtrap / SMTP
- **Purpose:** Email notifications (password reset, order confirmation)
- **Auth:** SMTP credentials in env vars
- **Template:** Pug for HTML email formatting

---

## Environment Variables

### Backend (`config/config.env`)

```
# Server
PORT=4000
NODE_ENV=DEVELOPMENT|PRODUCTION

# Database
DB_LOCAL_URI=mongodb+srv://user:pass@cluster.mongodb.net/Internship

# Frontend URL (CORS)
FRONTEND_URL=http://localhost:3000

# JWT
JWT_SECRET=<long-random-key>
JWT_EXPIRES_TIME=90

# Cloudinary (Image CDN)
CLOUDINARY_CLOUD_NAME=<cloud-name>
CLOUDINARY_API_KEY=<api-key>
CLOUDINARY_API_SECRET=<api-secret>

# Email (Mailtrap)
EMAIL_HOST=sandbox.smtp.mailtrap.io
EMAIL_PORT=25
EMAIL_USERNAME=<mailtrap-user>
EMAIL_PASSWORD=<mailtrap-pass>
EMAIL_FROM=noreply@orderit.com

# Stripe (Payments)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_API_KEY=pk_test_...
```

### Frontend (`public/index.html` / CRA env)
Frontend env vars are set at build time:
```
REACT_APP_STRIPE_PUBLIC_KEY=pk_test_...
```

---

## Running Locally

### Prerequisites
- Node.js 18+
- npm 9+
- MongoDB Atlas account with connection URI
- Cloudinary account
- Stripe test keys
- Mailtrap account

### Setup & Run

**Backend:**
```bash
cd app/backend

# 1. Update config/config.env with your Atlas URI, Stripe keys, Cloudinary keys, etc.
# 2. Install deps
npm install --legacy-peer-deps

# 3. Start development server
NODE_ENV=DEVELOPMENT nodemon server.js
# Server runs on http://localhost:4000
```

**Frontend:**
```bash
cd app/frontend

# 1. Install deps
npm install --legacy-peer-deps

# 2. Start dev server
npm start
# App runs on http://localhost:3000
# Automatically proxies /api/v1/* to http://localhost:4000 (see package.json "proxy")
```

### Testing API
```bash
# Get all restaurants
curl http://localhost:4000/api/v1/eats/stores

# Get menus
curl http://localhost:4000/api/v1/eats/menus
```

---

## Code Quality Notes

### ⚠️ Critical Issue: Code Obfuscation

**Files:** `backend/app.js`, `backend/server.js`, `backend/config/database.js` (and possibly others)

**Problem:**
- Obfuscated with javascript-obfuscator (string-array + bytecode dispatch)
- Unreadable to humans and most static analysis tools
- Blocks meaningful code review, security audits, and AI-assisted debugging
- Makes maintenance, onboarding, and infrastructure changes harder

**Recommendation:**
- **De-obfuscate immediately** before any production deployment
- Use a deobfuscator (e.g., js-beautify, de4js online)
- Commit the readable source
- Use build-time obfuscation only if needed (e.g., post-build minification for secrets)

---

## Security Considerations

1. **JWT Storage:** Frontend currently stores JWT in localStorage (vulnerable to XSS). Consider httpOnly cookies for prod.
2. **Secrets in Code:** Avoid hardcoding API keys. All external service keys must come from environment variables only.
3. **Stripe Key Exposure:** Public key (`pk_test_...`) can be in frontend env; secret key must never be exposed.
4. **Password Hashing:** Uses bcryptjs (✓). Ensure salt rounds ≥ 10 in controller.
5. **CORS:** Frontend URL should be restricted in production (not `*`).
6. **Email Headers:** Ensure Mailtrap credentials are never logged or exposed in error messages.

---

## Deployment Checklist

- [ ] Remove/de-obfuscate `app.js`, `server.js`
- [ ] Add health check endpoint (e.g., `GET /health` → `{ status: "ok" }`)
- [ ] Implement structured logging (not just console.log)
- [ ] Set up error tracking (e.g., Sentry)
- [ ] Validate all env vars at startup
- [ ] Add request/response logging middleware
- [ ] Implement rate limiting for auth routes
- [ ] Add input validation & sanitization (currently missing)
- [ ] Set up database connection pooling for prod
- [ ] Create Docker images for both backend & frontend
- [ ] Set up K8s manifests & Helm charts (see INFRA_DESIGN.md)

---

## Related Documentation
- **Infrastructure Design:** See `INFRA_DESIGN.md` for Kubernetes & Terraform architecture
- **Deployment:** Jenkinsfile exists but only does checkout + npm install (incomplete)
