using Repositories.Interfaces;
using Services.Interfaces;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services
{
    public class LicenseService : ILicenseService
    {
        private readonly ILicenseRepository _licenseRepository;
        private readonly ICryptoService _cryptoService;
        public LicenseService(ILicenseRepository licenseRepository, ICryptoService cryptoService)
        {
            _licenseRepository = licenseRepository;
            _cryptoService = cryptoService;
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
                response.Valid = IsValid(license.LicenseKey);
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
                string decryptedKey = _cryptoService.Decrypt(license.LicenseKey);
                if (DateTime.TryParse(decryptedKey, out DateTime licenseValidity))
                {
                    return DateTime.Now < licenseValidity;
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

        public bool IsValid(string key)
        {
            try
            {
                string decryptedKey = _cryptoService.Decrypt(key);
                if (DateTime.TryParse(decryptedKey, out DateTime licenseValidity))
                {
                    return DateTime.Now < licenseValidity;
                }
                else
                {
                    return false;
                }
            }
            catch(Exception ex)
            {
                throw new Exceptions.InvalidKeyException();
            }
            
        }

        public void Update(Models.Licenses.License license)
        {
            if (IsValid(license.LicenseKey))
            {
                Models.Licenses.License _license =GetLicenseByType(license.LicenseType);
                if (_license != null)
                {
                    _licenseRepository.Update(license);
                }
                else
                {
                    _licenseRepository.Add(license);
                }
            }
            else
            {
                throw new Exceptions.KeyExpiredException();
            }
        }
    }
}
