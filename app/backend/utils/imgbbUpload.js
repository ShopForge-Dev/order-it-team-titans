const axios = require('axios');
const FormData = require('form-data');

exports.uploadToImgBB = async (fileBuffer, filename) => {
  try {
    const formData = new FormData();
    formData.append('image', fileBuffer, filename);
    formData.append('key', process.env.IMGBB_API_KEY);

    const response = await axios.post('https://api.imgbb.com/1/upload', formData, {
      headers: formData.getHeaders(),
    });

    if (response.data.success) {
      return {
        url: response.data.data.url,
        public_id: response.data.data.id,
        deleteUrl: response.data.data.delete_url,
      };
    } else {
      throw new Error('ImgBB upload failed');
    }
  } catch (error) {
    throw new Error(`Image upload error: ${error.message}`);
  }
};

exports.deleteFromImgBB = async (deleteUrl) => {
  try {
    await axios.get(deleteUrl);
    return true;
  } catch (error) {
    console.error('ImgBB delete error:', error.message);
    return false;
  }
};
