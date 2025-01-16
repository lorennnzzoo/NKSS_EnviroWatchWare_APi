using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class CompanyService : ICompanyService
    {
        private readonly ICompanyRepository _companyRepository;

        // Constructor for dependency injection
        public CompanyService(ICompanyRepository companyRepository)
        {
            _companyRepository = companyRepository;
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
            _companyRepository.Add(company);
        }

        public void UpdateCompany(Company company)
        {
            _companyRepository.Update(company);
        }

        public void DeleteCompany(int id)
        {
            _companyRepository.Delete(id);
        }
    }

}
