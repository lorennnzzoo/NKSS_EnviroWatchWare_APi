using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;

namespace Services
{
    public class LicenseService : ILicenseService
    {
        private readonly ILicenseRepository _licenseRepository;
        private readonly ICryptoService _cryptoService;
        private readonly IUserService _userService;
        private readonly IRoleService _roleService;
        private string LICENSE_URL;
        private const string LICENSE_TYPE= "WatchWare";
        public LicenseService(ILicenseRepository licenseRepository, ICryptoService cryptoService, IUserService userService, IRoleService roleService)
        {
            _licenseRepository = licenseRepository;
            _cryptoService = cryptoService;
            _userService = userService;
            _roleService = roleService;
            LICENSE_URL = System.Configuration.ConfigurationManager.AppSettings["LicenseUrl"];
        }

        public void AddLicense(Models.Licenses.License license)
        {
            Models.Licenses.License licenseExists= _licenseRepository.GetLicenseByType(license.LicenseType);
            if (licenseExists != null)
            {
                throw new Exceptions.LicenseTypeAlreadyExistsException(license.LicenseType);
            }
            _licenseRepository.Add(license);
        }

        public void DeleteLicenes(string licenseType)
        {
            _licenseRepository.Delete(licenseType);
        }

        public Models.Licenses.LicenseResponse GetLicenseResponseByType(string licenseType)
        {
            Models.Licenses.LicenseResponse response = new Models.Licenses.LicenseResponse();

            var license= _licenseRepository.GetLicenseByType(licenseType);
            if (license != null)
            {
                response.LicenseType = license.LicenseType;
                response.LicenseKey = license.LicenseKey;
                response.Valid = license.Active;
            }
            
            return response;
        }

        public Models.Licenses.License GetLicenseByType(string licenseType)
        {
            

            var license = _licenseRepository.GetLicenseByType(licenseType);
            

            return license;
        }

        public bool IsLicenseValid(string licenseType)
        {
            var license = _licenseRepository.GetLicenseByType(licenseType);
            if(license != null)
            {
                //string decryptedKey = _cryptoService.Decrypt(license.LicenseKey);
                //if (DateTime.TryParse(decryptedKey, out DateTime licenseValidity))
                //{
                //    return DateTime.Now < licenseValidity;
                //}
                //else
                //{
                //    return false;
                //}    
                if (license.Active)
                {
                    return true;
                }
                else
                {
                    return false;
                }
            }
            else
            {
                return false;
            }                        
        }

        //public bool IsValid(string key)
        //{
        //    try
        //    {
        //        string decryptedKey = _cryptoService.Decrypt(key);
        //        if (DateTime.TryParse(decryptedKey, out DateTime licenseValidity))
        //        {
        //            return DateTime.Now < licenseValidity;
        //        }
        //        else
        //        {
        //            return false;
        //        }
        //    }
        //    catch(Exception ex)
        //    {
        //        throw new Exceptions.InvalidKeyException();
        //    }
            
        //}

        public void Update(Models.Licenses.License license)
        {
            //if (IsValid(license.LicenseKey))
            //{
            //    Models.Licenses.License _license =GetLicenseByType(license.LicenseType);
            //    if (_license != null)
            //    {
            //        _licenseRepository.Update(license);
            //    }
            //    else
            //    {
            //        _licenseRepository.Add(license);
            //    }
            //}
            //else
            //{
            //    throw new Exceptions.KeyExpiredException();
            //}
            Models.Licenses.License _license = GetLicenseByType(license.LicenseType);
            if (_license != null)
            {
                _licenseRepository.Update(license);
            }
            else
            {
                _licenseRepository.Add(license);
            }
        }
        

        public Models.Licenses.ProductDetails GetProductSoftwareTrack(string key)
        {
            string apiUrl = $"{LICENSE_URL}License/GetProductDetailsByLicenseKey?licenseKey={key}";
            Models.Licenses.ProductDetails details = new Models.Licenses.ProductDetails();

            using (HttpClient client = new HttpClient())
            {
                HttpResponseMessage response = client.GetAsync(apiUrl).Result;

                if (response.IsSuccessStatusCode)
                {
                    string detailsString = response.Content.ReadAsStringAsync().Result;
                    details = Newtonsoft.Json.JsonConvert.DeserializeObject<Models.Licenses.ProductDetails>(detailsString);
                    return details;
                }
                else if (response.StatusCode == System.Net.HttpStatusCode.NotFound)
                {
                    return null;
                }
                else
                {
                    return null;
                }
            }
        }

        public void RegisterProduct(Models.Licenses.ProductDetails product)
        {
            var licenseStatus=GetLicenseStatus();
            if (licenseStatus == null)
            {
                Models.Licenses.License license = new Models.Licenses.License
                {
                    Active = true,
                    LicenseKey = product.licenseKey,
                    LicenseType = LICENSE_TYPE,
                };
                Update(license);
                _roleService.CreateAdminRole();
                
                _userService.CreateAdminAccount(product.UserDetails.Password,product.UserDetails.Email,product.UserDetails.PhoneNumber);
            }
            else if (!licenseStatus.Active)
            {
                Models.Licenses.License license = new Models.Licenses.License
                {
                    Active = true,
                    LicenseKey = product.licenseKey,
                    LicenseType = LICENSE_TYPE,
                };
                Update(license);
                _roleService.CreateAdminRole();
                
                _userService.CreateAdminAccount(product.UserDetails.Password, product.UserDetails.Email, product.UserDetails.PhoneNumber);
            }
            else
            {
                throw new ArgumentException("Product already registered.");
            }
        }

        public Models.Licenses.License GetLicenseStatus()
        {
            return _licenseRepository.GetLicenseByType(LICENSE_TYPE);
        }
    }
}
