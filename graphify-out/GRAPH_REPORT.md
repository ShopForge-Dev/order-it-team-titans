# Graph Report - .  (2026-08-15)

## Corpus Check
- 106 files · ~103,299 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 534 nodes · 793 edges · 33 communities (32 shown, 1 thin omitted)
- Extraction: 95% EXTRACTED · 5% INFERRED · 0% AMBIGUOUS · INFERRED: 42 edges (avg confidence: 0.56)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- Component 0
- Component 1
- Component 2
- Component 3
- Component 4
- Component 5
- Component 6
- Component 7
- Component 8
- Component 9
- Component 10
- Component 11
- Component 12
- Component 13
- Component 14
- Component 15
- Component 16
- Component 17
- Component 18
- Component 19
- Component 20
- Component 21
- Component 22
- Component 23
- Component 24
- Component 25
- Component 26
- Component 27
- Component 28
- Component 29
- Component 30
- Component 31
- Component 32

## God Nodes (most connected - your core abstractions)
1. `clearErrors()` - 11 edges
2. `getRestaurants()` - 9 edges
3. `clearErrors()` - 7 edges
4. `APIFeatures` - 6 edges
5. `Home()` - 6 edges
6. `Loader()` - 6 edges
7. `scripts` - 5 edges
8. `scripts` - 5 edges
9. `addItemToCart()` - 5 edges
10. `updateCartQuantity()` - 5 edges

## Surprising Connections (you probably didn't know these)
- `Menu()` --calls--> `getRestaurants()`  [EXTRACTED]
  app/frontend/src/components/Menu.js → app/frontend/src/actions/restaurantAction.js
- `ListOrders()` --calls--> `getRestaurants()`  [EXTRACTED]
  app/frontend/src/components/order/ListOrders.js → app/frontend/src/actions/restaurantAction.js
- `App()` --calls--> `loadUser()`  [EXTRACTED]
  app/frontend/src/App.js → app/frontend/src/actions/userActions.js
- `Cart()` --calls--> `addItemToCart()`  [EXTRACTED]
  app/frontend/src/components/cart/Cart.js → app/frontend/src/actions/cartActions.js
- `Fooditem()` --calls--> `addItemToCart()`  [EXTRACTED]
  app/frontend/src/components/Fooditem.js → app/frontend/src/actions/cartActions.js

## Import Cycles
- None detected.

## Communities (33 total, 1 thin omitted)

### Community 0 - "Component 0"
Cohesion: 0.04
Nodes (47): dependencies, axios, countries-list, country-list, @fortawesome/fontawesome-svg-core, @fortawesome/free-solid-svg-icons, @fortawesome/react-fontawesome, mdbreact (+39 more)

### Community 1 - "Component 1"
Cohesion: 0.09
Nodes (31): saveDeliveryInfo(), clearErrors(), createOrder(), getOrderDetails(), myOrders(), clearErrors(), forgotPassword(), loadUser() (+23 more)

### Community 2 - "Component 2"
Cohesion: 0.05
Nodes (37): dependencies, bcrypt, bcryptjs, cloudinary, cookie-parser, dotenv, express, express-fileupload (+29 more)

### Community 3 - "Component 3"
Cohesion: 0.15
Nodes (29): logout(), Header(), Search(), CLEAR_ERRORS, FORGOT_PASSWORD_FAIL, FORGOT_PASSWORD_REQUEST, FORGOT_PASSWORD_SUCCESS, LOAD_USER_FAIL (+21 more)

### Community 4 - "Component 4"
Cohesion: 0.07
Nodes (29): _0x38ce(), _0x449f(), catchAsyncErrors, { CloudinaryStorage }, createSendToken(), crypto, Email, ErrorHandler (+21 more)

### Community 5 - "Component 5"
Cohesion: 0.07
Nodes (27): _0x4299(), _0x481c(), app, auth, bodyParser, cloudinary, cookieParser, coupon (+19 more)

### Community 6 - "Component 6"
Cohesion: 0.08
Nodes (19): _0x1471(), _0x5382(), catchAsync, ErrorHandler, Menu, Restaurant, _0x1536(), _0x1866() (+11 more)

### Community 7 - "Component 7"
Cohesion: 0.17
Nodes (19): addItemToCart(), clearCart(), removeItemFromCart(), setRestaurantId(), updateCartQuantity(), getMenus(), Cart(), OrderSuccess() (+11 more)

### Community 8 - "Component 8"
Cohesion: 0.17
Nodes (18): getRestaurants(), sortByRatings(), sortByReviews(), toggleVegOnly(), CountRestaurant(), Home(), Message(), Restaurant() (+10 more)

### Community 9 - "Component 9"
Cohesion: 0.17
Nodes (20): CLEAR_ERRORS, CREATE_ORDER_FAIL, CREATE_ORDER_REQUEST, CREATE_ORDER_SUCCESS, MY_ORDER_FAIL, MY_ORDER_REQUEST, MY_ORDER_SUCCESS, ORDER_DETAILS_FAIL (+12 more)

### Community 10 - "Component 10"
Cohesion: 0.09
Nodes (22): browserslist, development, production, eslintConfig, extends, name, private, proxy (+14 more)

### Community 11 - "Component 11"
Cohesion: 0.13
Nodes (14): author, description, devDependencies, nodemon, license, main, name, scripts (+6 more)

### Community 12 - "Component 12"
Cohesion: 0.15
Nodes (13): _0x1603(), _0x269e(), express, {
    getAllRestaurants,
    createRestaurant,
    getRestaurant,
    deleteRestaurant,
  }, menuRoutes, reviewRoutes, router, _0x1a39() (+5 more)

### Community 13 - "Component 13"
Cohesion: 0.16
Nodes (11): _0x223a(), _0x5815(), foodSchema, mongoose, _0x164d(), _0x1763(), { connect }, connectDatabase (+3 more)

### Community 14 - "Component 14"
Cohesion: 0.22
Nodes (9): _0x3570(), _0x45b8(), catchAsync, Coupon, ErrorHandler, _0x1d68(), _0x488b(), couponSchema (+1 more)

### Community 15 - "Component 15"
Cohesion: 0.20
Nodes (5): _0x3b6d(), _0x41df(), htmlToText, nodemailer, pug

### Community 16 - "Component 16"
Cohesion: 0.25
Nodes (8): _0x1c35(), _0x3f5f(), bcrypt, crypto, jwt, mongoose, userSchema, validator

### Community 17 - "Component 17"
Cohesion: 0.25
Nodes (8): _0x2948(), _0xdd06(), app, cloudinary, connectDatabase, dotenv, server, { setDriver }

### Community 18 - "Component 18"
Cohesion: 0.29
Nodes (7): _0x4ad2(), _0x5ac3(), catchAsyncErrors, ErrorHandler, FoodItem, { ObjectId }, Order

### Community 19 - "Component 19"
Cohesion: 0.25
Nodes (7): background_color, display, icons, name, short_name, start_url, theme_color

### Community 20 - "Component 20"
Cohesion: 0.46
Nodes (5): GET_MENU_FAIL, GET_MENU_REQUEST, GET_MENU_SUCCESS, initialState, menuReducer()

### Community 21 - "Component 21"
Cohesion: 0.33
Nodes (6): _0x31b2(), _0x3df8(), mongoose, Restaurant, Review, reviewSchema

### Community 22 - "Component 22"
Cohesion: 0.33
Nodes (6): _0x234f(), _0x57fa(), authController, express, { processPayment, sendStripApi }, router

### Community 23 - "Component 23"
Cohesion: 0.40
Nodes (5): _0x250d(), _0x5d59(), catchAsyncErrors, dotenv, stripe

### Community 24 - "Component 24"
Cohesion: 0.40
Nodes (5): _0x3a82(), _0x4d40(), AppError, catchAsync, Review

### Community 25 - "Component 25"
Cohesion: 0.40
Nodes (5): _0x3252(), _0x55ba(), authController, express, router

### Community 26 - "Component 26"
Cohesion: 0.40
Nodes (5): _0x4b03(), _0xae6f(), {
    createCoupon,
    getCoupon,
    updateCoupon,
    deleteCoupon,
    couponValidate,
  }, express, router

### Community 27 - "Component 27"
Cohesion: 0.40
Nodes (5): _0x2de8(), _0x4048(), express, { getAllMenus, createMenu, deleteMenu }, router

### Community 28 - "Component 28"
Cohesion: 0.40
Nodes (5): _0x15ec(), _0xcbab(), express, Restaurant, router

### Community 29 - "Component 29"
Cohesion: 0.50
Nodes (3): _0x1bb5(), _0x4428(), mongoose

### Community 30 - "Component 30"
Cohesion: 0.50
Nodes (4): _0x1c32(), _0x46e5(), menuSchema, mongoose

### Community 31 - "Component 31"
Cohesion: 0.50
Nodes (4): _0x1b76(), _0x49e2(), mongoose, orderSchema

## Knowledge Gaps
- **206 isolated node(s):** `express`, `app`, `path`, `cookieParser`, `bodyParser` (+201 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `dependencies` connect `Component 0` to `Component 10`?**
  _High betweenness centrality (0.015) - this node is a cross-community bridge._
- **Why does `dependencies` connect `Component 2` to `Component 11`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `express`, `app`, `path` to the rest of the system?**
  _206 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Component 0` be split into smaller, more focused modules?**
  _Cohesion score 0.0425531914893617 - nodes in this community are weakly interconnected._
- **Should `Component 1` be split into smaller, more focused modules?**
  _Cohesion score 0.09065679925994449 - nodes in this community are weakly interconnected._
- **Should `Component 2` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._
- **Should `Component 3` be split into smaller, more focused modules?**
  _Cohesion score 0.1495798319327731 - nodes in this community are weakly interconnected._