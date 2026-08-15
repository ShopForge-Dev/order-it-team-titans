const mongoose = require('mongoose');
const dotenv = require('dotenv');
const axios = require('axios');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../config/config.env') });

const Restaurant = require('../models/restaurant');
const FoodItem = require('../models/foodItem');
const Menu = require('../models/menu');

// Sample restaurant and food data with Unsplash image URLs
const restaurantsData = [
  {
    name: 'Pizza Palace',
    address: '123 Main Street, Downtown',
    isVeg: false,
    location: {
      type: 'Point',
      coordinates: [40.7128, -74.0060],
    },
    foods: [
      {
        name: 'Margherita Pizza',
        description: 'Classic Italian pizza with fresh basil and mozzarella',
        price: 12.99,
        image: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?w=400',
      },
      {
        name: 'Pepperoni Pizza',
        description: 'Delicious pepperoni with extra cheese',
        price: 14.99,
        image: 'https://images.unsplash.com/photo-1628840042765-356cda07f4ab?w=400',
      },
    ],
    restaurantImage: 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=400',
  },
  {
    name: 'Burger Barn',
    address: '456 Oak Avenue, Midtown',
    isVeg: false,
    location: {
      type: 'Point',
      coordinates: [40.7580, -73.9855],
    },
    foods: [
      {
        name: 'Classic Cheeseburger',
        description: 'Juicy beef patty with melted cheddar cheese',
        price: 10.99,
        image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
      },
      {
        name: 'Bacon Burger',
        description: 'Topped with crispy bacon and special sauce',
        price: 12.99,
        image: 'https://images.unsplash.com/photo-1553979459-d2229ba7433b?w=400',
      },
    ],
    restaurantImage: 'https://images.unsplash.com/photo-1555939594-58d7cb561482?w=400',
  },
  {
    name: 'Sushi House',
    address: '789 Elm Street, Uptown',
    isVeg: false,
    location: {
      type: 'Point',
      coordinates: [40.7614, -73.9776],
    },
    foods: [
      {
        name: 'Salmon Sushi Roll',
        description: 'Fresh salmon with rice and nori',
        price: 11.99,
        image: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400',
      },
      {
        name: 'California Roll',
        description: 'Crab, avocado, and cucumber roll',
        price: 9.99,
        image: 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=400',
      },
    ],
    restaurantImage: 'https://images.unsplash.com/photo-1553869459-d2229ba7433b?w=400',
  },
  {
    name: 'Veggie Delight',
    address: '321 Green Lane, Parkside',
    isVeg: true,
    location: {
      type: 'Point',
      coordinates: [40.7489, -73.9680],
    },
    foods: [
      {
        name: 'Buddha Bowl',
        description: 'Mixed vegetables with quinoa and tahini dressing',
        price: 10.99,
        image: 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=400',
      },
      {
        name: 'Veggie Burger',
        description: 'Plant-based burger with avocado and sprouts',
        price: 10.49,
        image: 'https://images.unsplash.com/photo-1585238341710-4b51926670b7?w=400',
      },
    ],
    restaurantImage: 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=400',
  },
];

async function uploadImageToImgBB(imageUrl, filename) {
  try {
    const response = await axios.get(imageUrl, { responseType: 'arraybuffer' });
    const buffer = Buffer.from(response.data);

    const formData = new FormData();
    const blob = new Blob([buffer], { type: 'image/jpeg' });
    formData.append('image', blob, filename);
    formData.append('key', process.env.IMGBB_API_KEY);

    const uploadResponse = await axios.post('https://api.imgbb.com/1/upload', formData, {
      headers: formData.getHeaders?.() || { 'Content-Type': 'multipart/form-data' },
    });

    if (uploadResponse.data.success) {
      return {
        url: uploadResponse.data.data.url,
        public_id: uploadResponse.data.data.id,
      };
    }
  } catch (error) {
    console.error(`Failed to upload ${filename}:`, error.message);
    return null;
  }
}

async function seedDatabase() {
  try {
    await mongoose.connect(process.env.DB_LOCAL_URI);
    console.log('Connected to MongoDB');

    // Clear existing data
    await Restaurant.deleteMany({});
    await FoodItem.deleteMany({});
    await Menu.deleteMany({});
    console.log('Cleared existing data');

    // Seed restaurants with foods
    for (const restaurantData of restaurantsData) {
      console.log(`\nProcessing ${restaurantData.name}...`);

      // Upload restaurant image
      const restaurantImg = await uploadImageToImgBB(
        restaurantData.restaurantImage,
        `${restaurantData.name.replace(/\s+/g, '_')}_restaurant.jpg`
      );

      const images = restaurantImg ? [restaurantImg] : [];

      // Create restaurant
      const restaurant = await Restaurant.create({
        name: restaurantData.name,
        address: restaurantData.address,
        isVeg: restaurantData.isVeg,
        location: restaurantData.location,
        images,
      });

      console.log(`✓ Created restaurant: ${restaurant.name}`);

      // Upload food images and create food items
      const foodItems = [];
      for (const foodData of restaurantData.foods) {
        const foodImg = await uploadImageToImgBB(
          foodData.image,
          `${foodData.name.replace(/\s+/g, '_')}.jpg`
        );

        const foodItem = await FoodItem.create({
          name: foodData.name,
          description: foodData.description,
          price: foodData.price,
          images: foodImg ? [foodImg] : [],
          restaurant: restaurant._id,
        });

        foodItems.push(foodItem._id);
        console.log(`  ✓ Added food: ${foodData.name}`);
      }

      // Create menu
      const menu = await Menu.create({
        restaurant: restaurant._id,
        items: foodItems,
      });

      console.log(`✓ Created menu with ${foodItems.length} items`);
    }

    console.log('\n✅ Database seeded successfully!');
    process.exit(0);
  } catch (error) {
    console.error('Seed error:', error);
    process.exit(1);
  }
}

seedDatabase();
