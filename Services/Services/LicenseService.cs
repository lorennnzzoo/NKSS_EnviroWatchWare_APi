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
        public bool IsLicenseValid(string licenseType)
        {
            var license = _licenseRepository.GetLicenseByType(licenseType);
            string decryptedKey = _cryptoService.Decrypt(license.LicenseKey);           
            if (DateTime.TryParse(decryptedKey, out DateTime licenseValidity))
            {             
                return DateTime.Now < licenseValidity;
            }           
            return false;
        }

    }
}
