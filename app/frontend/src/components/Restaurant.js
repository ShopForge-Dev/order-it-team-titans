import React from 'react'
import {Link} from "react-router-dom";

const Restaurant = ({restaurant}) => {
  if (!restaurant) {
    return <div>Loading...</div>;
  }

  const imageUrl = restaurant.images && restaurant.images.length > 0
    ? restaurant.images[0].url
    : '/default-restaurant.png';

  const ratingWidth = restaurant.ratings ? (restaurant.ratings / 5) * 100 : 0;
  const reviews = restaurant.numOfReviews || 0;

  return (
    <div className="col-sm-12 col-md-6 col-lg-3 my-3">
                <div className="card p-3 rounded">
                    <Link
                     to={`eats/stores/${restaurant._id}/menus`}
                     className = "btn btn-block"
                    >
                    <img
                     className="card-img-top mx-auto"
                     src={imageUrl}
                    alt={restaurant.name || 'Restaurant'}
                    ></img>
                    </Link>
                    <div className="card-body d-flex flex-column">
                        <h5 className="card-title">{restaurant.name || 'Unnamed'}</h5>
                        <p className="rest_adress">
                            {restaurant.address || 'Address not available'}
                        </p>
                        <div className="ratings mt-auto">
                            <div className="rating-outer">
                                <div className="rating-inner"
                                 style ={{width: `${ratingWidth}%` }}
                                ></div>
                                 </div>

                            <span id="no_of_reviews">({reviews} Reviews)</span>

                        </div>
                    </div>
                </div>
            </div>
  );
};

export default Restaurant
