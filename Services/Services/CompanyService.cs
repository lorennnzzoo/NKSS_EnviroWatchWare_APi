using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;
using System;

namespace Services
{
    public class CompanyService : ICompanyService
    {
        private readonly ICompanyRepository _companyRepository;
        private readonly IStationService stationService;

        // Constructor for dependency injection
        public CompanyService(ICompanyRepository companyRepository, IStationService _stationService)
        {
            _companyRepository = companyRepository;
            stationService = _stationService;
        }

        public IEnumerable<Company> GetAllCompanies()
        {
            return _companyRepository.GetAll();
        }

        public Company GetCompanyById(int id)
        {
            return _companyRepository.GetById(id);
        }

        public void CreateCompany(Post.Company company)
        {
            IEnumerable<Company> companies=_companyRepository.GetAll().Where(e=>e.Active==true);
            if (companies .Count()>0)
            {
                throw new Exceptions.CompaniesLimitReachedException();
            }
            _companyRepository.Add(company);
        }

        public void UpdateCompany(Models.Put.Company company)
        {
            _companyRepository.Update(company);
        }

        public void DeleteCompany(int id)
        {
            var stationsLinkedToCompany = stationService.GetAllStationsByCompanyId(id).ToList();
            if (stationsLinkedToCompany.Any())
            {
                foreach(var station in stationsLinkedToCompany)
                {
                    stationService.DeleteStation(Convert.ToInt32( station.Id));
                }
            }
            _companyRepository.Delete(id);
        }
    }

}
