# FuzzyInfer

## Where it's used

* [Brighter Planet CM1 Impact Estimate web service](http://impact.brighterplanet.com) 

## What it does

FuzzyInfer predicts one or more unknown characteristics of an input case by comparing its known characteristics to a reference dataset whose records contain both the known and unknown characteristics. It weights these records according to how closely they match the input case on known characteristics, and then performs a weighted average of the records to predict the unknown characteristics.

## Tuning your parameters

As you're iteratively tinkering with the two equations for Sigma and compound weighting scheme, it may be helpful to monitor the effects of various options on the distribution of membership weights, both for each variable and for the final compound weights. It's important to note that the two equations aren't independent, such that they must be developed in tandem to get the desired results across the range of possible input values.

#### Determining Sigma:

The value of Sigma determines the width of the membership function curve for a given variable, and hence the number of records that will be taken into account. Tuning Sigma to fit your desired results for your application is a subjective process based on how wide a net you want to cast around your input value.

Sigma does NOT have to be the same for all variables in the fuzzy analysis -- you can tweak it independently for each variable.

Sigma can be coded as either:

* A constant.
* A function of all X values.
  * In this case a reasonable default is to set Sigma equal to the standard deviation of variable X. This ensures that regardless of the range covered by X, your fuzzy membership function will capture a nice subset of the records.
* A function both of all X values and of Mu.

Remember that if compound fuzzy weighting is being employed to analyze multiple variables (see below), the effect of your weight compounding formula on the width of your final net should be accounted for, as it will either expand or contract the net.

##### Case study

Brighter Planet's [lodging model](http://impact.brighterplanet.com/models/lodging) uses compound fuzzy inference on six variables in the US EIA CBECS data set to predict hotel energy use.

1. To keep things simple we developed an equation for Sigma that works for all six variables, but we could have tweaked them individually if we'd wanted.
2. We started by setting Sigma at `STDDEV_SAMP(x)`.
3. For most Mu values this ended up including too many records for our taste, so we experimented with fractions of the standard deviation of x, like `STDDEV_SAMP(x) / 3`.
4. This worked ok for Mu values close to the mean, but for Mu values near or beyond the range limits of the CBECS data set where records were much more sparse, it wasn't capturing enough records for a reasonable sample size.
5. We decided to develop a formula that increased the value of Sigma (the width of the net) as Mu got farther away from the mean. This would allow us to cast a wide net when dealing with sparse edge cases but a narrow net when Mu is in the densely-populated center of the data set. We accomplished this by incorporating `ABS(AVG(X) - Mu)` into our equation.
6. After some more tinkering--including looking at the number of records that would ultimately be highly-weighted for various input combinations after our particular weight compounding formula was applied--we settled on a final formula to use for our Sigma equation for all of our variables: `STDDEV_SAMP(x) / 5 + (ABS(AVG(x) - Mu) / 3)`.

#### Determining compound weighting scheme:

The compound weighting formula comes into play when performing fuzzy inferences based on more than one known variable.

For each record in your reference data set, it takes its calculated normalized membership value for each variable you're using for inference, and consolidates those weights into a single membership value for that record.

Note that these starting weights are all between 0 and 1, and that they've been normalized so that the weight for the heaviest record is exactly 1.

How you want to determine your final membership weights depends on a couple key questions:

* How exclusive you want your fuzzy analysis to be, i.e. how closely a record must match your input case to be worthy of a relatively high weight
* The relative importance of the variables that are driving your inference scheme, i.e. whether you give more predictive credence to some than others

You could do all kinds of fun formulas, but there are two primary operations for compounding variable weights:

###### Addition
* This is the more inclusive operation, as all records that resemble the input case in at least one respect will be given some weight.
* Relative variable weights can be incorporated by multiplying the variable's weight by the record's membership value during addition.

###### Multiplication
* This is the more exclusive operation, as a record that's dissimilar to the input case in any respect will end up with a low final weight.
* Relative variable weights can be incorporated by raising the record's membership value to the power of that variable's weight during multiplication.
  * Note that since membership values are between 0 and 1, raising them to higher powers produces lower values, such that more important variables should be raised to lesser powers than unimportant variables.
  * Also note that unlike in additive compounding, with multiplicative compounding the absolute (not just relative) values of the variable do affect the final distribution of weights -- raising all your variables to the power of 2 is NOT the same as raising all your variables to the power of 0.5.

These two primary operations can be mixed as needed to meet the needs of your particular application. A combination of addition and multiplication may make sense for many data sets.

##### Case study

Brighter Planet's lodging model uses compound fuzzy inference to predict hotel energy use based on six variables in the CBECS data set: number of rooms, number of floors, heating degree days, cooling degree days, construction year, and percent air conditioned.

1. We wanted to perform our inference based only on records that closely matched our input case for most of these variables, so we started with a straight multiplication scheme rather than addition.
2. We recognized that number of rooms and number of floors would be highly correlated, as would number of heating and cooling degree days, so we didn't want to treat them independently. For these paired variables, we also wanted records that were similar in one but not both respects to retain some, albeit lesser, weight.
3. We wanted to weight climate and hotel size more heavily than construction year and air conditioning.
4. We settled on the equation `(POW(rooms, 0.8) + POW(floors, 0.8)) * (POW(hdd, 0.8) + POW(cdd, 0.8)) * POW(year, 0.8) * POW(ac, 0.8)`
5. This effectively weights hotel size and climate more heavily than the other variables, because the addition allows weights for these variables to range up to 2 whereas the other two variables have max weights of 1.
6. It also allows a record to be dissimilar to the input case on half of a variable pair without being disqualified, provided it's a close match on the other half.

## Setup

1) gem install a bleeding edge earth

    cd earth
    git pull
    gem build earth.gemspec
    gem install earth-0.11.10.gem --ignore-dependencies --no-rdoc --no-ri

2) create your test database

    mysql -u root -ppassword -e "create database test_fuzzy_infer charset utf8"

3) load cbecs (just the first time - note that it is hardcoded to ONLY run cbecs data_miner)

    RUN_DATA_MINER=true rake

## Further testing

    rake

## Future plans

**in the future the fuzzy inference machine will make TEMPORARY tables, rather than gum up your db**

for now, it makes permanent tables so that you can examine them

wishlist:

* re-use FIM for multiple targets
* cache #fuzzy_infer
* randomize names of all added columns
* use arel to generate sql(?)

## Database compatibility

* mysql
* postgresql

## Copyright

Copyright 2012 Brighter Planet, Inc.
